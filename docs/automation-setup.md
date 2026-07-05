# CI/CD Automation Setup

## Implemented Flows

1. PR to `main`
- `PR CI` runs a Debug simulator build + unit tests, then a signing-disabled Release device build (catches Release-only build errors before merge).
- `CodeRabbit Review Request` posts `@coderabbitai review` to trigger CodeRabbit.

2. Merge to `main` (push event)
- `TestFlight` (`.github/workflows/testflight.yml`) archives the app (automatic signing via the App Store Connect API key), exports with manual signing (imported distribution cert + provisioning profile), and uploads the build to TestFlight via `altool`.
- Build number = UTC timestamp (`yyyyMMddHHmm`), so re-runs and workflow renames never collide with a previously uploaded build.
- App Store review submission is **manual** (see Release Procedure below). No AI release-note generation.

3. Main branch protection
- Configure Rulesets in GitHub UI:
  - direct push blocked (PR required),
  - `PR CI / build-and-test` required.

## Required Configuration

### Environment `app-store-production` — Secrets
- `APP_STORE_CONNECT_KEY_ID`: ASC API key ID.
- `APP_STORE_CONNECT_ISSUER_ID`: ASC issuer ID.
- `APP_STORE_CONNECT_PRIVATE_KEY`: Base64 of the ASC API key `.p8` content.
- `DIST_CERT_P12`: Base64 of the Apple Distribution certificate `.p12` (with private key).
- `DIST_CERT_PASSWORD`: password of that `.p12`.
- `PROV_PROFILE_APP`: Base64 of the App Store provisioning profile for `com.J.BodyLapse`, named exactly `BodyLapse AppStore`.

The workflow validates all six at the start of every run and fails fast with the missing name if any is empty.

### Repository variable (NOT environment-scoped)
- `TESTFLIGHT_ENABLED` = `true` — the deploy job is skipped until this exists. It must be a **repository** variable; environment-scoped variables are invisible to the job-level `if`.

### Environment protection
- `app-store-production` has a deployment branch policy restricting deployments to `main` (also enforced by a `github.ref` check in the workflow).

## Release Procedure

1. Bump `MARKETING_VERSION` in `BodyLapse.xcodeproj/project.pbxproj` (both Debug and Release blocks) and update `docs/release_notes.json` (locales: `ja`, `en-US`, `es-ES`, `ko`).
2. Merge to `main` → the TestFlight workflow uploads the build automatically (or run it manually via `workflow_dispatch` on `main`).
3. In App Store Connect: create the new version, select the uploaded build, paste "What's New" for each locale from `docs/release_notes.json`, and submit for review.

## Notes

- Do **not** upload archives built locally in Xcode: the project pins `CURRENT_PROJECT_VERSION = 1`, which is lower than every CI build number and will be rejected by App Store Connect. Use `workflow_dispatch` on `main` instead.
- The fastlane/match pipeline and AI release-note generation were removed in July 2026 (the match secrets and `OPENAI_API_KEY` are no longer used by any workflow).
