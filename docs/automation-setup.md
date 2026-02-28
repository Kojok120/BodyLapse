# CI/CD Automation Setup

## Implemented Flows

1. PR to `main`
- `PR CI` runs build + unit tests.
- `CodeRabbit Review Request` posts `@coderabbitai review` to trigger CodeRabbit.

2. Merge to `main` (push event)
- `Release to App Store` generates `What's New` in `ja/en/es/ko` using AI.
- The workflow builds an IPA and submits it to App Store Connect for review.

3. Main branch protection
- Configure Rulesets in GitHub UI:
  - direct push blocked (PR required),
  - at least 1 PR approval,
  - `PR CI / build-and-test` required,
  - stale review dismissal,
  - admins also enforced.

## Required Secrets

### For release note generation
- `OPENAI_API_KEY`: API key used to generate 4-language release notes.

### For App Store Connect upload
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY` (Base64 encoded `.p8` content)

### For code signing (choose one path)

1. Manual assets on runner
- `BUILD_CERTIFICATE_BASE64` (`.p12` Base64)
- `P12_PASSWORD`
- `BUILD_PROVISION_PROFILE_BASE64` (`.mobileprovision` Base64)
- `KEYCHAIN_PASSWORD`

2. fastlane match (recommended)
- `MATCH_GIT_URL`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION` (optional, for HTTPS auth)

## One-time Setup Steps

1. Install and enable the CodeRabbit GitHub App on this repository.
2. Add required GitHub Secrets listed above.
3. Configure branch protection Rulesets in GitHub settings:
   - `Require a pull request before merging`: enabled
   - `Require approvals`: 1+
   - `Require status checks`: `PR CI / build-and-test`
   - `Include administrators`: enabled

## Notes

- Release workflow uses commit range `${before}..${after}` from push event.
- If release note generation fails, App Store submission stops.
- Locale codes used for App Store release notes:
  - Japanese: `ja`
  - English: `en-US`
  - Spanish: `es-ES`
  - Korean: `ko`
