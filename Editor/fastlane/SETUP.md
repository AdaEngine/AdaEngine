# App Store Connect builds

Run commands from `Editor/`. Fastlane generates `AdaEditor.xcodeproj` from
`project.yml`, archives the `AdaEditor-iPadOS` scheme in Release, and exports an
App Store IPA. The public configuration contains only the bundle ID
`org.adaengine.editor` and development team `8PYCRS3EA3`.

## Upload either platform with the Xcode account

For a Mac already signed into the developer account in Xcode, use automatic
signing and Xcode's App Store Connect upload. This route does not require the
Fastlane API key or a manually selected distribution profile:

```bash
BUILD_NUMBER=2 MARKETING_VERSION=1.0 bundle exec fastlane upload_xcode target:ios
BUILD_NUMBER=2 MARKETING_VERSION=1.0 bundle exec fastlane upload_xcode target:macos
```

Choose the version and build number before running. Archives and logs are saved
under `build/appstore/ios` and `build/appstore/macos`. The lane verifies the
archive's signature, bundle ID, version, and build number before uploading.
Xcode may raise the uploaded build number if needed to avoid a collision.
`ADAEDITOR_DERIVED_DATA` can point to an existing task-owned build cache.

To retry an upload from the same archive, pass `skip_archive:true` with the same
target, `BUILD_NUMBER`, and `MARKETING_VERSION`. The account must be authorized
to use automatic distribution signing. Upload completion does not establish
Apple's processing result; check the build in App Store Connect afterward.

## Prerequisites

- macOS with Xcode 26.2 or newer, its iOS SDK, and command-line tools selected.
- Ruby 3.3, Bundler 2.6.0, and XcodeGen (`brew install xcodegen`).
- The complete AdaEngine checkout, including Git submodules
  (`git submodule update --init --recursive` from the repository root).
- An Apple Distribution certificate **with its private key** already installed
  in an unlocked keychain, plus an installed App Store provisioning profile for
  this bundle ID and team. The profile must support the app's Game Center entitlement.
- For uploads: an existing iOS app record in App Store Connect and a team API key
  with permission to upload builds (Developer or higher).

```bash
gem install bundler -v 2.6.0
bundle _2.6.0_ install
cp fastlane/.env.example fastlane/.env
```

Edit the ignored `fastlane/.env`: set `IOS_PROVISIONING_PROFILE` to the exact
installed profile name, `BUILD_NUMBER` to a positive integer higher than the last
uploaded build for this version, and optionally `MARKETING_VERSION` (default `0.1.0`).
Build numbers are explicit: no Apple credentials or network query are needed to
choose one. Coordinate numbers between local and CI uploads.

## Build only

```bash
bundle exec fastlane ios build
```

No App Store Connect credentials are needed for this lane. It uses local signing
assets and does not log in to Apple or download/create certificates or profiles.
Package resolution may still require network access. Manual signing is applied
only to the generated iPadOS Release target and restored after the build.

Outputs are under the ignored `Editor/build/testflight/` directory:
`AdaEditor.ipa`, `AdaEditor.xcarchive`, dSYMs, build logs, and isolated DerivedData.
Each run reuses these output paths; copy artifacts elsewhere if retaining builds.

## Build and upload

Supply `ASC_KEY_ID` and `ASC_ISSUER_ID` privately, and exactly one of:

- `ASC_KEY_FILEPATH`: path to a private `.p8` file outside the checkout. Relative
  paths resolve from `Editor/`.
- `ASC_KEY_BASE64`: Base64-encoded `.p8` contents, suitable for a CI secret.
  Base64 is an encoding, not encryption; this value is a secret too.

```bash
bundle exec fastlane ios beta
```

The lane uploads the newly built IPA and returns without waiting for Apple's
processing. It does not submit for external beta review or configure tester groups.
Check processing, export compliance, and tester availability in App Store Connect.

## Public repository and CI

Commit the Gemfile, lockfile, Fastfile, and empty `.env.example`. Keep Apple account
credentials, API key IDs/issuer IDs and private keys in an ignored local `.env` or
your CI secret store. Do not pass secrets as command-line lane options or print
the environment. Team ID and provisioning profile names may be public.

For CI, install the certificate/private key into a temporary unlocked keychain
and install the profile before running the lane. Inject API variables from the
secret store, use a unique `BUILD_NUMBER`, then remove signing material and the
temporary keychain in an unconditional cleanup step. This configuration deliberately
does not contain signing assets, a credentials repository, or Apple login details.

The editor's `.gitignore` excludes local env files, common signing file formats,
Fastlane API-key JSON files, and build artifacts. Ignore rules are a guardrail;
review staged files before publishing, and never force-add signing material.

References: [Fastlane build_app](https://docs.fastlane.tools/actions/build_app/),
[API key authentication](https://docs.fastlane.tools/actions/app_store_connect_api_key/),
[TestFlight uploads](https://docs.fastlane.tools/actions/testflight/).
