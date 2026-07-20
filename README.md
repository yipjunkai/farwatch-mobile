# farwatch-mobile

[![TestFlight](https://github.com/yipjunkai/farwatch-mobile/actions/workflows/testflight.yml/badge.svg)](https://github.com/yipjunkai/farwatch-mobile/actions/workflows/testflight.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/yipjunkai/farwatch-mobile/badge)](https://scorecard.dev/viewer/?uri=github.com/yipjunkai/farwatch-mobile)
[![License: MIT OR Apache-2.0](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue.svg)](#-license)

**The Farwatch client for iOS and Android.** Watch and steer your terminal AI agent from your phone over an end-to-end encrypted connection — a structured native UI for Claude Code, plus a full terminal mirror for any tool. Flutter. Zero-knowledge relay. Crypto verified against the Rust core.

Run `farwatch start claude` on your machine ([farwatch CLI](https://github.com/yipjunkai/farwatch)), scan the QR code with this app, and you're connected.

> **ℹ️ Status** — Companion client to [**farwatch**](https://github.com/yipjunkai/farwatch), kept public so the client-side crypto is auditable. This is a personal project, not actively developed as a product — issues and PRs may not get timely responses.

## 📱 What it does

Two views over the same encrypted session, toggled from the app bar.

**Structured view** (Claude Code) — renders the agent's activity as native cards instead of raw terminal text:

- Thinking blocks, streaming text, and markdown
- Tool-call cards with parsed arguments
- Tool results (truncated)
- Permission requests as tap-to-approve/deny cards
- Todo lists, cost ticker, typing indicator
- Telegram-style prompt bar with a mic button

**Terminal view** (any tool) — a full [xterm](https://pub.dev/packages/xterm) mirror of the host PTY, with a bottom sheet for terminal actions (Ctrl+C, arrows, paste).

## ✨ Features

- **End-to-end encrypted** — X25519 key exchange, HKDF-SHA256, AES-256-GCM, exactly matching the [farwatch protocol](https://github.com/yipjunkai/farwatch); the relay only ever sees ciphertext
- **QR-code pairing** — scan to connect, with host public-key fingerprint verification against MITM
- **Deep-link pairing** — `farwatch://` URIs open straight into a session
- **Speech-to-text prompts** — dictate to your agent with on-device recognition, edit before sending
- **Session history** — revisit recent sessions
- **iOS + Android** — one Flutter codebase

## 🏗️ Built with

| Concern          | Package                                                             |
| ---------------- | ------------------------------------------------------------------ |
| State management | `flutter_riverpod`                                                 |
| Terminal         | `xterm`                                                            |
| Crypto           | `cryptography` / `cryptography_flutter` (X25519, AES-GCM, HKDF)    |
| Wire format      | `msgpack_dart` (compatible with the Rust `rmp-serde` protocol)     |
| Transport        | `web_socket_channel`                                               |
| QR scanning      | `mobile_scanner`                                                   |
| Speech           | `speech_to_text`                                                   |
| Deep links       | `app_links`                                                        |

## 🚀 Development

Requires [FVM](https://fvm.app/) (pinned to `stable`) and CocoaPods for iOS.

```bash
fvm install && fvm use
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter run
```

## 🧪 Testing

Tests run against shared Rust test vectors (`test/fixtures/rust_test_vectors.json`) to prove the Dart crypto and protocol implementations stay byte-compatible with the Rust core.

```bash
flutter test
```

## 🍎 iOS signing

Signing config lives in `ios/Flutter/Signing.xcconfig`. Certificates and provisioning profiles are managed by [Fastlane Match](https://docs.fastlane.tools/actions/match/) and stored encrypted in a separate private repo.

```bash
cd ios
bundle install
MATCH_GIT_URL=... MATCH_PASSWORD=... ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_CONTENT=... \
  bundle exec fastlane sync_certs
```

## 🚢 Deployment

Push a version tag to trigger a TestFlight build via GitHub Actions:

```bash
git tag v0.2.1
git push origin v0.2.1
```

Version comes from the tag, build number from `github.run_number`. See `.github/workflows/testflight.yml` and `ios/fastlane/Fastfile`.

## 📄 License

Dual-licensed under [MIT](LICENSE-MIT) or [Apache 2.0](LICENSE-APACHE), at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in **farwatch-mobile** by you, as defined in the Apache-2.0 license, shall be dually licensed as above, without any additional terms or conditions.
