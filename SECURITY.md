# Security Policy

## Supported versions

farwatch-mobile is solo-maintained: only the **most recent released version**
(the latest tag / TestFlight build) receives security fixes. Older versions are
not patched — update to the current build before reporting.

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Use GitHub's private security advisory mechanism:

1. Go to <https://github.com/yipjunkai/farwatch-mobile/security/advisories>
2. Click "Report a vulnerability"
3. Fill in the form with as much detail as you can share

Acknowledgement is targeted within 72 hours. There is no separate email contact at this stage; the GitHub advisory channel is the only supported route.

## What to report

- **Cryptographic implementation flaws** — client-side X25519 / HKDF-SHA256 / AES-256-GCM handling, nonce or replay handling, or pairing-fingerprint verification that diverges from the [farwatch protocol](https://github.com/yipjunkai/farwatch) and weakens the end-to-end guarantee
- **Local exposure of session data** — decrypted terminal content, session keys, or history reachable by other apps, device backups, logs, or the clipboard beyond what the user intends
- **Pairing / deep-link handling** — a hostile `farwatch://` URI or QR code that could redirect a session, leak the pairing secret, or bypass fingerprint verification
- **Supply-chain concerns** — dependency vulnerabilities not yet flagged by Dependabot

## What is not in scope

- **Compromised devices** — a jailbroken/rooted or malware-infected phone already holds the decrypted session
- **Traffic analysis** — message timing and sizes are visible to the relay by design
- **Relay or CLI issues** — report those against [farwatch](https://github.com/yipjunkai/farwatch/security/advisories), not here
- Feature requests or general bugs (open a regular issue)
