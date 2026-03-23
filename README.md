# farwatch-mobile

Flutter mobile client for Farwatch. Connects to a desktop host via encrypted WebSocket relay.

## Setup

Requires [FVM](https://fvm.app/) (pinned to `stable`) and CocoaPods for iOS.

```bash
fvm install && fvm use
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter run
```

## Testing

Tests run against shared Rust test vectors (`test/fixtures/rust_test_vectors.json`) for crypto and protocol compatibility.

```bash
flutter test
```

## iOS Signing

Signing config lives in `ios/Flutter/Signing.xcconfig`. Certs and profiles are managed by Fastlane Match (stored encrypted in a private repo).

```bash
cd ios
bundle install
MATCH_GIT_URL=... MATCH_PASSWORD=... ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_CONTENT=... \
  bundle exec fastlane sync_certs
```

## Deployment

Push a version tag to trigger a TestFlight build via GitHub Actions:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Version comes from the tag, build number from `github.run_number`. See `.github/workflows/testflight.yml` and `ios/fastlane/Fastfile`.
