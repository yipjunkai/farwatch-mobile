# Mobile App Brainstorm / Proto-TODO

Ideas for the Terminal Relay Flutter app, organized by theme. These are candidates for future roadmap items -- not yet committed to a phase.

---

## UX & Interaction

### 1. Gesture-based terminal control
Swipe gestures mapped to common actions: swipe-left for Ctrl-C, swipe-up for scroll-back, pinch-to-zoom for font size, two-finger swipe for tab switching. Reduces dependence on the toolbar.

### 2. Radial/pie menu for commands
Long-press anywhere on the terminal to open a radial menu with the most-used actions (interrupt, clear, paste, resize). Faster than scrolling through the toolbar, especially one-handed.

### 3. Smart input bar (hybrid chat + terminal)
A text input field above the keyboard that lets you compose multi-line prompts before sending, with a "send" button. Typing directly into a terminal on mobile is painful -- this gives you an editor-like compose experience with draft saving, history recall, and auto-complete from recent commands.

### 4. Prompt templates / quick commands
User-defined snippet library: "fix the failing tests", "explain this error", "commit with message: ___". Tap to send, with placeholder fill-in. Saves repetitive typing on a phone keyboard.

### 5. Haptic + audio feedback for agent state
Distinct vibration patterns for: agent started thinking, agent waiting for approval, agent finished task, session disconnected. Lets you pocket the phone and still know what's happening.

### 6. Picture-in-picture / floating window
On Android, support PiP mode so you can monitor terminal output while using other apps. On iOS, use Live Activities on the lock screen to show agent status (idle/busy/waiting).

---

## Agent-Aware Features

### 7. Approval queue as native UI
Parse agent output for tool-use approval prompts (Claude's `y/n`, Copilot's confirmations) and surface them as native iOS/Android notification-style cards with approve/reject buttons. No need to read terminal output to approve file writes.

### 8. Structured diff viewer
When the agent produces a file diff, detect it and render a native side-by-side or inline diff view with syntax highlighting. Much more readable than ANSI diff output on a small screen.

### 9. Agent output summarization
Periodically summarize long terminal output into a collapsible "what happened" card using on-device LLM (Apple Intelligence / Gemini Nano). Useful when you glance at your phone after 10 minutes and want a quick catch-up.

### 10. Task timeline / activity feed
A secondary view that shows a timeline of agent actions: "Modified 3 files", "Ran tests (2 failed)", "Waiting for approval". Parsed from terminal output patterns. Gives a high-level overview without reading raw terminal scrollback.

### 11. Error detection + suggested actions
Detect common error patterns in output (stack traces, compilation errors, test failures) and surface a "Retry", "Ask agent to fix", or "Copy error" action card inline.

---

## Multi-Session & Workspace

### 12. Session dashboard with live previews
A grid/list view showing all active sessions with tiny live-updating terminal thumbnails (like macOS Mission Control). Tap to expand. Shows agent name, status (busy/idle/waiting), and last output line.

### 13. Session groups by project
Group sessions by project/repo. "Backend API" has Claude working on it, "Frontend" has Copilot. Color-coded, with aggregate status ("2 agents busy, 1 waiting").

### 14. Broadcast mode
Type a command once and send it to multiple sessions simultaneously. Useful for "stop all agents" or "git status" across projects.

### 15. Session handoff / share
Generate a one-time link to hand a session to a teammate. They scan the QR and get read-only (or read-write) access. Useful for pair programming or "hey, look at what my agent is doing."

---

## Voice & Accessibility

### 16. Continuous listening mode
"Hey Terminal" wake word detection (on-device) that starts capturing a voice command without touching the phone. Ideal for when your phone is propped up on a desk.

### 17. Voice command chaining
"Run tests, and if they pass, commit with message 'fix auth bug'" -- parsed into conditional sequential commands. Goes beyond simple speech-to-text.

### 18. Dictation with context awareness
When dictating code or commands, use the current terminal context (language, framework, recent output) to improve speech-to-text accuracy. "import fastAPI" shouldn't become "import fast a p i."

---

## Notifications & Monitoring

### 19. Smart notification batching
Don't spam notifications. Batch agent activity into periodic summaries: "In the last 5 minutes: Claude modified 4 files, tests are passing." Configurable frequency.

### 20. Watch expressions
Set up regex watches: "notify me when `BUILD SUCCESSFUL` appears" or "alert me on any Python traceback." Custom triggers on terminal output patterns without constant monitoring.

### 21. Idle cost awareness
If using cloud-hosted AI (API-based agents), estimate and show cost accumulation. "Claude has been idle for 15 minutes, ~$0 cost. Active for 23 minutes, ~$2.40 estimated." Helps with budget awareness.

---

## Offline & Local

### 22. Session recording & playback
Record terminal sessions (with timestamps) and replay them later -- like asciinema but built-in. Useful for reviewing what an agent did overnight, or for creating demos.

### 23. Offline command queue
When disconnected, let users queue up commands that auto-send when the connection resumes. "I know I'll want to run tests when it reconnects."

### 24. Local terminal mode
Use the same app as a local terminal on the phone (via Termux integration on Android, or a-Shell on iOS). No relay needed. Makes the app useful even without a desktop session, and builds muscle memory.

---

## Polish & Delight

### 25. Themes and customization
Terminal color schemes (Dracula, Solarized, Nord, Catppuccin), custom fonts (JetBrains Mono, Fira Code, etc.), and background opacity. People care about their terminal aesthetic.

### 26. Widget support
iOS home screen widget and Android widget showing current session status, last output line, and a quick-action button to send Ctrl-C or open the app.

### 27. Shortcuts / Siri integration
iOS Shortcuts action: "Start a Claude session on my Mac." Siri: "Hey Siri, what's my agent doing?" Returns the last few lines of output or a status summary.

### 28. Onboarding walkthrough
Animated tutorial on first launch showing: install CLI -> run `terminal-relay start` -> scan QR -> you're in. With a "demo mode" that connects to a fake session so users can try the UI before setting up the CLI.
