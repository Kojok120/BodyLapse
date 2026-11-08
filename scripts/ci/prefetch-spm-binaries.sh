#!/bin/bash
# SwiftPM のバイナリのうち GitHub のリリースから落とすもの (opencv2.xcframework.zip) を、
# API 経由で先に SwiftPM のキャッシュへ置く。
#
# 2026-11-08 に github.com/<owner>/<repo>/releases/download/... が 504 を返し続け、
# パッケージの解決で止まった (API の assets エンドポイントは通っていた)。
# SwiftPM は URL から作った名前のファイルがキャッシュにあればそれを使い、
# パッケージに書かれたチェックサムで中身を確かめる。取り違えても解決が失敗するだけで、壊れたものは使われない。
#
# 使い方: GH_TOKEN を渡して実行する (gh CLI を使う)
set -euo pipefail

resolved="BodyLapse.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
cache="$HOME/Library/Caches/org.swift.swiftpm/artifacts"
mkdir -p "$cache"

version="$(python3 -c "import json,sys; d=json.load(open('$resolved')); print(next(p['state']['version'] for p in d['pins'] if p['identity']=='opencv-spm'))")"
url="https://github.com/yeatse/opencv-spm/releases/download/${version}/opencv2.xcframework.zip"
# SwiftPM のキャッシュ名: URL の英数字以外を _ に置き換えたもの
name="$(printf '%s' "$url" | sed 's/[^A-Za-z0-9]/_/g')"
dest="$cache/$name"

if [ -s "$dest" ]; then
  echo "cached: $dest"
  exit 0
fi

asset_api="$(gh api "repos/yeatse/opencv-spm/releases/tags/${version}" --jq '.assets[] | select(.name=="opencv2.xcframework.zip") | .url')"
echo "prefetch opencv2.xcframework.zip ${version} via ${asset_api}"
curl -fsSL --retry 5 --retry-delay 10 \
  -H "Accept: application/octet-stream" \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -o "$dest.partial" "$asset_api"
mv "$dest.partial" "$dest"
ls -l "$dest"
