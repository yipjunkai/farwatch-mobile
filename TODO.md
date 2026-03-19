# Terminal Relay App - TODO

Current state: production-quality release build on Android. E2E encrypted terminal mirroring with auto-reconnect, explicit state machine, terminal toolbar, deep links, app lifecycle handling, and cross-platform tested protocol/crypto layers. 58 tests passing.

## Architecture issues to fix

### RelayClient (WebSocket layer)

- [x] Replace custom message buffering with callback-based architecture. Registration handled internally, messages buffered and delivered after.
- [x] Add automatic reconnect with exponential backoff (1s to 30s, max 10 attempts).
- [ ] Add WebSocket ping/pong keepalive at the transport level (not just relay-level `Ping`/`Pong`). Mobile OS kills idle connections aggressively.
- [x] Add connection timeout handling -- 15s timeout on WebSocket connect and registration.
- [x] Handle app lifecycle: pause heartbeats when backgrounded, reconnect immediately when foregrounded. `reconnectNow()` bypasses backoff delay.
- [x] Add proper close/dispose lifecycle -- intentional close flag prevents reconnect, disposed flag prevents notification after dispose.

### RelaySession (handshake + E2E channel)

- [x] Rewrite as explicit state machine with 8 states: `disconnected -> connecting -> waitingForPeer -> handshaking -> awaitingConfirm -> connected`, plus `reconnecting` and `error`.
- [x] Fix handshake race condition with frame queue. All frames during async key derivation are queued and processed sequentially after.
- [x] Add handshake timeout -- 15s timer across `waitingForPeer`, `handshaking`, and `awaitingConfirm`. Resends handshake on timeout, or triggers full reconnect if connection lost.
- [ ] Handle the dual-handshake pattern correctly. Both sides send Handshake simultaneously. The client should process the first Handshake it receives and ignore duplicates rather than resetting state.
- [ ] Add session resumption -- after reconnect, attempt to re-establish the secure channel without a full handshake if the relay accepted the resume token.
- [ ] Replace `debugPrint` with a proper logging/event system that is stripped in release builds.

### Protocol layer

- [x] Round-trip tests for all message types verified against Rust-generated MessagePack bytes. 24 protocol tests.
- [x] Handle `msgpack_dart` type quirks: `List<dynamic>` cast to `Uint8List` via `_toUint8List`.
- [x] Handle unit enum variant encoding (bare strings) for `KeepAlive`, `Heartbeat`.
- [ ] Add protocol version to the Dart Handshake so the host can detect old mobile clients.

### Crypto layer

- [x] Unit tests verified against Rust test vectors: key derivation, fingerprint, MAC, AES-GCM encrypt/decrypt, replay detection. 13 crypto tests.
- [ ] Verify constant-time MAC comparison actually works in Dart. Consider using a crypto library's built-in compare if available.
- [ ] Handle key material cleanup -- null out key references when the session ends.

## UI / UX issues

### Navigation

- [x] Fix black screen on disconnect. Back button uses `pushReplacement` to scan screen.
- [x] Handle Android back button -- prompts "Disconnect?" dialog when connected, navigates back directly when disconnected/errored. Uses `PopScope`.
- [ ] Add a home screen between scan and terminal: show session history, reconnect options, settings.

### Terminal screen

- [x] Reconnect button in status bar and app bar when connection is error/disconnected.
- [x] Status bar shows all 8 states with distinct icons and colors.
- [x] Terminal toolbar with Ctrl keys (C, D, Z, L, A, E, R, W), Tab, Esc, arrow keys, Paste, and common symbols (/, |, ~). Toggleable via app bar icon. Haptic feedback on taps. Horizontally scrollable rows.
- [ ] Add a reconnect overlay when connection drops -- show error message with reconnect/close buttons instead of just a small icon in the status bar.
- [ ] Support landscape orientation for more terminal columns.

### Scan screen

- [x] Camera permission error handling -- shows icon, explains issue, offers "Try again" button. Specific messages for permission denied vs. unsupported vs. other errors.
- [x] Loading state with spinner while camera initializes.
- [x] Manual URI paste always available even when camera fails.
- [ ] Validate the pairing URI before navigating -- check that the relay URL is reachable.
- [ ] Support scanning from the photo gallery (screenshot of QR code).

### Error handling

- [x] Error states show message and reconnect action. No more silent failures.
- [ ] Add a global error boundary that catches unhandled exceptions and shows a recovery screen.
- [ ] Surface crypto errors clearly: "Fingerprint mismatch" should explain what it means and what to do.

## Features

### Reconnect (done)

- [x] Auto-reconnect when WebSocket drops (exponential backoff, max 10 attempts).
- [x] Preserve terminal buffer across reconnects -- only the session state resets, not the visible output.
- [x] Show reconnect progress in status bar.
- [x] Manual retry button when reconnect fails.

### Deep links (done)

- [x] Register `termrelay://` scheme handler on Android (intent filter in AndroidManifest.xml + MainActivity.kt MethodChannel).
- [x] Register `termrelay://` scheme handler on iOS (CFBundleURLTypes in Info.plist).
- [x] Route handler in main.dart: checks initial link on cold start, listens for links on warm start, navigates directly to terminal screen.

### App lifecycle (done)

- [x] Pause heartbeats when app is backgrounded.
- [x] Reconnect immediately when app is foregrounded if connection was lost.

### Settings

- [ ] Add a settings screen: default relay URL, terminal font size, theme (dark/light/custom), haptic feedback toggle.
- [ ] Persist settings with `shared_preferences`.

### Session management

- [ ] Show active/recent sessions on the home screen.
- [ ] Allow reconnecting to a previous session by tapping it (if the host is still running).
- [ ] Show session metadata: tool name, host fingerprint, connection duration, data transferred.

## Testing

- [x] Unit tests for pairing URI parsing (valid, invalid, missing fields). 9 tests.
- [x] Unit tests for protocol encoding/decoding with Rust-generated bytes. 24 tests.
- [x] Unit tests for crypto with Rust test vectors. 13 tests.
- [x] Widget test: app launches to scan screen.
- [ ] Add widget tests for terminal screen and status bar states.
- [ ] Add integration test: mock WebSocket server that replays a captured Rust handshake sequence, verify the Dart client completes the handshake and decrypts output.

## Build / Release

- [x] Release APK builds and runs on Android device.
- [ ] Set up app signing for Android (keystore) for Play Store distribution.
- [ ] Set up app signing for iOS (provisioning profiles, certificates).
- [ ] Add app icons and splash screen.
- [ ] Set up CI (GitHub Actions) for building and testing on push.
- [ ] Remove debug logging before release builds (use `kReleaseMode` checks or a log framework).
