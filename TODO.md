# Terminal Relay App - TODO

Current state: working demo with E2E encrypted terminal mirroring via Flutter. Connects to relay, completes X25519 handshake, renders PTY output. But fragile -- race conditions in handshake, no reconnect, poor error handling, black screens on failure.

## Architecture issues to fix

The core problem is that `RelayClient` and `RelaySession` were written as a quick proof-of-concept. They need to be rebuilt with proper patterns.

### RelayClient (WebSocket layer)

- [ ] Replace custom message buffering (`Queue<RelayMessage>` + callback swapping) with a proper stream architecture. Current approach loses messages and breaks on re-listen.
- [ ] Add automatic reconnect with exponential backoff (1s to 30s, max 10 attempts). Match the Rust CLI behavior. Reconnect should use the `resume_token` from the original registration.
- [ ] Add WebSocket ping/pong keepalive at the transport level (not just relay-level `Ping`/`Pong`). Mobile OS kills idle connections aggressively.
- [ ] Add connection timeout handling -- if the WebSocket doesn't connect within 15s, surface an error instead of hanging.
- [ ] Handle app lifecycle: pause heartbeats when app is backgrounded, reconnect when foregrounded.
- [ ] Add proper close/dispose lifecycle -- currently closing during an active handshake or mid-message causes unhandled exceptions.

### RelaySession (handshake + E2E channel)

- [ ] Rewrite as a proper state machine with explicit transitions instead of scattered boolean flags (`_confirmed`, `_handshakeInProgress`, `_pendingConfirm`). States: `disconnected -> connecting -> registering -> waitingForPeer -> handshaking -> confirming -> connected`. No implicit state from combinations of nullable fields.
- [ ] Fix the handshake race condition properly. Current issue: `deriveSessionKeys` is async, and `HandshakeConfirm` arrives before it completes. The buffering fix works but is fragile. Solution: queue all incoming frames during handshake and process them sequentially after key derivation completes.
- [ ] Handle the dual-handshake pattern correctly. Both sides send Handshake simultaneously. The client should process the first Handshake it receives and ignore duplicates rather than resetting state.
- [ ] Add handshake timeout -- if handshake doesn't complete within 10s, retry or surface an error.
- [ ] Add session resumption -- after reconnect, attempt to re-establish the secure channel without a full handshake if the relay accepted the resume token.
- [ ] Separate concerns: the session should not directly call `debugPrint`. Use a proper logging/event system.

### Protocol layer

- [ ] Add round-trip tests for all message types to verify wire compatibility with the Rust implementation. Capture known-good MessagePack bytes from Rust and verify Dart decodes them identically.
- [ ] Handle `msgpack_dart` type quirks properly. Document that `List<dynamic>` (not `List<int>` or `Uint8List`) is what msgpack returns for binary data. The `_toUint8List` cast should be the norm, not a workaround.
- [ ] Add protocol version to the Dart Handshake so the host can detect old mobile clients.

### Crypto layer

- [ ] Add unit tests for Dart crypto that verify against known Rust test vectors (same key pair -> same shared secret -> same derived keys -> same ciphertext for a given nonce).
- [ ] Verify constant-time MAC comparison actually works in Dart (the `|=` loop). Consider using a crypto library's built-in compare if available.
- [ ] Handle key material cleanup -- Dart doesn't have `ZeroizeOnDrop`, but we should at least null out key references when the session ends.

## UI / UX issues

### Navigation

- [ ] Fix black screen on disconnect. The `pushReplacement` from scan -> terminal means there's nothing to go back to. Navigation should use a proper router (go_router or similar) with named routes.
- [ ] Add a home screen between scan and terminal: show session history, reconnect options, settings.
- [ ] Handle Android back button properly -- should prompt "Disconnect?" instead of just crashing or going to black.

### Terminal screen

- [ ] Add a reconnect overlay when connection drops -- show error message with reconnect/close buttons instead of just a small icon in the status bar.
- [ ] Handle keyboard properly on mobile -- the xterm.dart keyboard input may not work well for all key combinations. Test Ctrl, Alt, arrow keys, Tab.
- [ ] Add a floating action button or gesture for common actions (paste, Ctrl-C, Ctrl-D, etc.) since mobile keyboards lack these.
- [ ] Fix terminal sizing -- send resize on initial connect and when orientation changes.
- [ ] Add haptic feedback on key presses.
- [ ] Support landscape orientation for more terminal columns.

### Scan screen

- [ ] Add camera permission error handling -- show a message if camera permission is denied instead of a blank screen.
- [ ] Add a loading state while camera initializes.
- [ ] Validate the pairing URI before navigating -- check that the relay URL is reachable.
- [ ] Support scanning from the photo gallery (screenshot of QR code).

### Error handling

- [ ] Every error state should have a clear message and an action (retry, go back, etc.). No blank screens, no silent failures.
- [ ] Add a global error boundary that catches unhandled exceptions and shows a recovery screen.
- [ ] Add timeout feedback -- if connecting takes more than 3s, show a spinner with "Connecting to relay..." text.
- [ ] Surface crypto errors clearly: "Fingerprint mismatch" should explain what it means and what to do.

## Features

### Reconnect (critical)

- [ ] Auto-reconnect when WebSocket drops (network change, app resume, server restart).
- [ ] Preserve terminal buffer across reconnects -- only the session state resets, not the visible output.
- [ ] Show reconnect progress in the status bar: "Reconnecting (attempt 2/10)..."
- [ ] If reconnect fails after all attempts, show a manual retry option.

### Deep links

- [ ] Register `termrelay://` scheme handler on Android (intent filter in AndroidManifest.xml).
- [ ] Register `termrelay://` scheme handler on iOS (URL types in Info.plist).
- [ ] When the app opens via deep link, go directly to the terminal screen (skip camera).

### Settings

- [ ] Add a settings screen: default relay URL, terminal font size, theme (dark/light/custom), haptic feedback toggle.
- [ ] Persist settings with `shared_preferences`.

### Session management

- [ ] Show active/recent sessions on the home screen.
- [ ] Allow reconnecting to a previous session by tapping it (if the host is still running).
- [ ] Show session metadata: tool name, host fingerprint, connection duration, data transferred.

## Testing

- [ ] Add widget tests for scan screen, terminal screen, and status bar.
- [ ] Add unit tests for pairing URI parsing (valid, invalid, missing fields, special characters).
- [ ] Add unit tests for protocol encoding/decoding with known Rust-generated bytes.
- [ ] Add unit tests for crypto (key derivation, encryption round-trip, MAC computation) with Rust test vectors.
- [ ] Add integration test: mock WebSocket server that replays a captured Rust handshake sequence, verify the Dart client completes the handshake and decrypts output.

## Build / Release

- [ ] Set up app signing for Android (keystore).
- [ ] Set up app signing for iOS (provisioning profiles, certificates).
- [ ] Add app icons and splash screen.
- [ ] Configure `flutter build apk --release` and `flutter build ios --release`.
- [ ] Set up CI (GitHub Actions) for building and testing on push.
- [ ] Remove debug logging before release builds.
