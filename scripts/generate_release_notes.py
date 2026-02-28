#!/usr/bin/env python3
"""
Generate App Store release notes in 4 locales from git diff and commits.

Output JSON format:
{
  "ja": "...",
  "en-US": "...",
  "es-ES": "...",
  "ko": "..."
}
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import textwrap
import urllib.error
import urllib.request
from pathlib import Path


REQUIRED_LOCALES = ("ja", "en-US", "es-ES", "ko")


def run_git(args: list[str]) -> str:
    result = subprocess.run(
        ["git", *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return result.stdout.strip()


def gather_context(from_sha: str, to_sha: str) -> tuple[str, str]:
    range_expr = f"{from_sha}..{to_sha}" if from_sha != to_sha else to_sha
    commits = run_git(["log", "--pretty=format:%h %s", range_expr, "--"])
    files = run_git(["diff", "--name-only", range_expr, "--"])

    if not commits:
        commits = run_git(["show", "--pretty=format:%h %s", "--no-patch", to_sha])
    if not files:
        files = "(no file path changes detected)"
    return commits, files


def extract_json_object(text: str) -> dict[str, str]:
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)

    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("Model output did not contain a JSON object.")

    payload = json.loads(text[start : end + 1])
    if not isinstance(payload, dict):
        raise ValueError("Model output JSON is not an object.")
    return payload


def validate_release_notes(payload: dict[str, str]) -> dict[str, str]:
    validated: dict[str, str] = {}
    missing = []
    for locale in REQUIRED_LOCALES:
        value = payload.get(locale)
        if not isinstance(value, str) or not value.strip():
            missing.append(locale)
            continue
        text = value.strip()
        if len(text) > 4000:
            raise ValueError(f"Release note for {locale} exceeds 4000 characters.")
        validated[locale] = text

    if missing:
        raise ValueError(f"Missing locale(s): {', '.join(missing)}")

    return validated


def call_openai(model: str, prompt: str, api_key: str) -> dict[str, str]:
    url = "https://api.openai.com/v1/chat/completions"
    body = {
        "model": model,
        "temperature": 0.2,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are an expert mobile release manager. "
                    "Return only JSON. No markdown."
                ),
            },
            {"role": "user", "content": prompt},
        ],
    }

    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"OpenAI API error: {exc.code} {detail}") from exc

    data = json.loads(raw)
    content = data["choices"][0]["message"]["content"]
    return extract_json_object(content)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--from-sha", required=True)
    parser.add_argument("--to-sha", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        print("OPENAI_API_KEY is required.", file=sys.stderr)
        return 1
    model = os.environ.get("OPENAI_MODEL", "gpt-4o-mini").strip()

    commits, files = gather_context(args.from_sha, args.to_sha)

    prompt = textwrap.dedent(
        f"""
        以下の更新情報をもとに、App Store の「What's New」文面を4言語で作成してください。
        対象言語は日本語・英語・スペイン語・韓国語です。

        制約:
        - 出力はJSONオブジェクトのみ
        - キーは必ず "ja", "en-US", "es-ES", "ko"
        - 各値はApp Store向けの自然な文面
        - 各言語 2-5 行程度（改行は使ってよい）
        - 誇張表現や未実装機能は書かない
        - 絵文字は使わない

        変更コミット:
        {commits}

        変更ファイル:
        {files}
        """
    ).strip()

    generated = call_openai(model=model, prompt=prompt, api_key=api_key)
    validated = validate_release_notes(generated)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(validated, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Wrote localized release notes to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
