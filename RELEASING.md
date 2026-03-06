# Releasing Fuji

Fuji is distributed as a signed, notarized macOS app via GitHub Releases, with in-app updates powered by [Sparkle 2](https://sparkle-project.org). There is no App Store listing — GitHub is the sole distribution channel.

This document covers the full release pipeline: how releases are triggered, what the CI workflow does, how secrets are managed, and how to perform common maintenance tasks.

## Overview

Releases follow this flow:

1. A maintainer pushes a SemVer git tag (e.g. `v0.2.0`).
2. A GitHub Actions workflow running on a self-hosted macOS runner builds, signs, notarizes, and packages the app.
3. The workflow creates a GitHub Release with the notarized ZIP and SHA-256 checksum.
4. The workflow updates the Sparkle appcast on GitHub Pages so existing users receive the update in-app.

Releases can also be triggered manually via `workflow_dispatch` in the GitHub Actions UI, where you provide the tag name explicitly.

## Prerequisites

### Apple Developer Program

Fuji is signed with a **Developer ID Application** certificate and notarized through Apple's notary service. This requires an active [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/year).

### Self-Hosted Runner

Because Fuji targets macOS 26+, and GitHub's hosted runners may not have the required SDK, a self-hosted macOS runner is used for release builds. The runner must have Xcode 26.x installed and be labeled `self-hosted` and `macOS` in GitHub Actions.

The runner does not need to be online 24/7. It only needs to be running when a release is triggered — if it's offline, jobs will queue until it comes back. Start the runner with `./run.sh` from its install directory before pushing a tag, and stop it when done.

### Sparkle Signing Keys

Fuji uses Sparkle's EdDSA signing for update verification. A keypair is generated once using Sparkle's `generate_keys` tool. The public key is embedded in `Info.plist` as `SUPublicEDKey`, and the private key is stored as a GitHub Actions secret (`SPARKLE_EDDSA_PRIVATE_KEY`).

## GitHub Secrets

The release workflow requires the following repository secrets:

| Secret | Description | Source |
|--------|-------------|--------|
| `APPLE_TEAM_ID` | 10-character Apple team ID | Apple Developer account or Xcode → Settings → Accounts |
| `DEVELOPER_ID_APP_P12_BASE64` | Base64-encoded Developer ID Application certificate (.p12) | Exported from Keychain Access → My Certificates |
| `DEVELOPER_ID_APP_P12_PASSWORD` | Password used when exporting the .p12 | Chosen during Keychain Access export |
| `NOTARY_APPLE_ID` | Apple ID email for notarization | Your Apple Developer account email |
| `NOTARY_APP_PASSWORD` | App-specific password for notarization | Generated at [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords |
| `SPARKLE_EDDSA_PRIVATE_KEY` | Sparkle EdDSA private key for signing updates | Output of Sparkle `generate_keys -x` |

All secrets should also be backed up in a password manager (e.g. 1Password) as the canonical recovery source. See [Disaster Recovery](#disaster-recovery) below.

To set secrets via the GitHub CLI:

```bash
gh secret set APPLE_TEAM_ID -b "YOUR_TEAM_ID"
gh secret set NOTARY_APPLE_ID -b "you@example.com"

# For passwords containing special characters like !, use read to avoid shell expansion:
read -s SECRET_VALUE
echo
gh secret set NOTARY_APP_PASSWORD -b "$SECRET_VALUE"
unset SECRET_VALUE

# Encode and store the .p12 certificate:
base64 -i /path/to/developer-id-app.p12 | gh secret set DEVELOPER_ID_APP_P12_BASE64
```

## Release Workflow

The release workflow (`.github/workflows/release.yml`) is triggered by pushing a tag matching `v*` or via manual `workflow_dispatch`. It runs on the self-hosted macOS runner and performs these steps:

1. **Checkout and test** — Checks out the tagged commit and runs the CI build/test script (unsigned, with OS-mismatch test skipping enabled).
2. **Download Sparkle tools** — Fetches the Sparkle release archive to obtain `sign_update` for EdDSA signing.
3. **Import signing certificate** — Decodes the `.p12` from secrets into a temporary keychain for code signing.
4. **Archive** — Builds a Release archive signed with Developer ID Application using `xcodebuild archive`. The version numbers (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`) are derived from the git tag.
5. **Export** — Exports the archive using the `developer-id` method with manual signing.
6. **Notarize and staple** — Submits a ZIP of the exported app to Apple's notary service, waits for approval, then staples the notarization ticket to the `.app` bundle.
7. **Package** — Creates the final distributable ZIP from the stapled app and generates a SHA-256 checksum.
8. **Sparkle signing** — Signs the final ZIP with the Sparkle EdDSA private key, producing the signature and file length needed for the appcast.
9. **GitHub Release** — Creates (or updates) a GitHub Release for the tag with the ZIP and checksum attached.
10. **Appcast update** — Checks out the `gh-pages` branch, inserts a new appcast item with the download URL, Sparkle signature, and version metadata, then pushes the updated `appcast.xml`. This is what allows existing installs to discover and download the update via Sparkle.
11. **Cleanup** — Removes the temporary keychain and certificate files (runs even if earlier steps fail).

## How to Cut a Release

1. Ensure all changes are merged to `main` and CI is green.
2. Start the self-hosted runner on your Mac.
3. Tag the release and push:

```bash
git tag -a v0.2.0 -m "v0.2.0"
git push origin v0.2.0
```

4. Monitor the release workflow in GitHub Actions.
5. Once complete, verify the GitHub Release page has the ZIP and checksum, and that the [appcast](https://uffelman.github.io/Fuji/updates/appcast.xml) contains the new version entry.
6. Stop the runner when done.

To trigger a release manually (e.g. to re-run for a tag that already exists), use the GitHub Actions UI: go to Actions → Release → Run workflow, and enter the tag name.

## CI Workflow (Non-Release)

The separate CI workflow (`.github/workflows/macos-ci.yml`) runs on every push and pull request using GitHub-hosted `macos-15` runners. It performs unsigned Debug and Release builds and runs unit tests when the OS version supports the deployment target. If the runner's macOS version is lower than the app's deployment target, tests are skipped gracefully.

A guard workflow (`.github/workflows/guard-no-hardcoded-team.yml`) ensures that hardcoded `DEVELOPMENT_TEAM` values are never committed to the project file.

## Sparkle In-App Updates

Fuji includes a "Check for Updates…" menu item powered by Sparkle 2. The update feed is hosted as a static `appcast.xml` on GitHub Pages at:

```
https://uffelman.github.io/Fuji/updates/appcast.xml
```

Sparkle is configured in `Info.plist` with the following behavior:

- **Automatic check on launch**: enabled (checks once per day).
- **Automatic silent install**: disabled — the user is prompted before installing.
- **Update channel**: stable only (no separate beta channel).

Users on versions released before Sparkle was integrated must manually download the first Sparkle-enabled release. All subsequent updates are delivered through the in-app updater.

## Homebrew

Fuji is not currently published to `homebrew/cask`. The official Homebrew cask registry has notability and maintenance thresholds that are premature for a new project. A maintainer-owned Homebrew tap may be added in the future once there is sufficient traction.

## Disaster Recovery

If the release machine is lost or needs to be replaced:

1. Provision a new Mac with the required macOS and Xcode versions.
2. Restore the `developer-id-app.p12` and its password from your password manager.
3. Import the Sparkle EdDSA private key back into the keychain using `generate_keys -f <private-key-file>`.
4. Install and configure a new GitHub Actions self-hosted runner.
5. Update GitHub secrets from password manager values if needed.
6. Run a test release to verify the full pipeline works and that existing clients can validate the update signature.

## Contributing

Contributors do not need Apple Developer credentials. The CI workflow builds and tests unsigned using `CODE_SIGNING_ALLOWED=NO`. To enable the pre-commit hook that prevents accidental hardcoded team IDs:

```bash
git config core.hooksPath .githooks
```
