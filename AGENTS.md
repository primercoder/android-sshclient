# AGENTS.md

## Project
Flutter Android SSH client — chat-style session management, SCP file transfer, LAN scanning.

## Key commands
| Command | Purpose |
|---------|---------|
| `flutter pub get` | install dependencies |
| `flutter analyze` | static analysis (uses `flutter_lints`) |
| `flutter test` | run tests |
| `flutter build apk --release --dart-define=source=process` | release APK (sqlite3 process hook) |
| `flutter build apk --debug --dart-define=source=process` | debug APK |
| `flutter run` | run on connected device/emulator |

Tests: `test/widget_test.dart` — placeholder smoke test only.

## Architecture
- **Entry**: `lib/main.dart` → `ProviderScope` → `App`
- **State management**: Riverpod (`NotifierProvider`, `FutureProvider`, `Provider`)
- **DB**: SQLite (`sqlite3` package, WAL mode, migrations by `PRAGMA user_version`)
- **SSH**: `dartssh2` — `SSHSocket.connect()` → `SSHClient()` → `authenticate`

### Directory layout
```
lib/
  main.dart, app.dart
  core/          — constants, theme
  data/
    database/    — AppDatabase (migrations + seeding), dao/
    models/      — 8 model classes
  providers/     — 5 Riverpod providers
  services/
    ssh/         — SshClientService (connect/execute/disconnect)
                   SshTerminalService (persistent shell via client.shell())
    scp/         — ScpTransferService (upload/download via SCP protocol)
    network/     — LanScanner (TCP port scanner, CIDR)
    crypto/      — KeyService (Ed25519 generate/import/export)
  ui/
    pages/       — 7 pages (home, chat, history, host_detail, scan, settings, transfers)
    widgets/chat — 6 chat widgets (new: terminal_screen.dart)
```

### SSH execution model
Commands are wrapped: `cd "<currentPwd>" && <userCommand> && pwd`
- Last line of output → new working directory (updates path bar, hidden from chat)
- Everything else → command output shown in chat bubble
- PTY width: 160 columns

### Session lifecycle
- `ChatNotifier._activeSessions: Map<sessionId, Session>` keeps sessions alive across page navigation
- Terminal mode uses `client.shell(pty:)` (persistent channel, not `client.execute`)
- Session ends only on explicit disconnect (not on chat page back)
- Reusing a session runs `cd "$lastDir" && pwd` to restore working directory

### SCP quirks
- Upload: raw SCP `-t` protocol with `StreamIterator` incremental ack reads
- Download: `SSH exec cat` (avoids SCP `-f` bidirectional protocol deadlock)
- SCP error detection via `\001` byte prefix (not stderr, to avoid deadlock)

### Terminal emulator mode
- Uses `xterm.dart` (`xterm: ^4.0.0`) with `Terminal` + `TerminalView`
- Shell session via `client.shell(pty:)` (persistent channel, not `client.execute`)
- `SshTerminalService` manages shell lifecycle; shares `SshClientService` SSH connection
- `TerminalScreen` widget contains full-screen terminal + bottom shortcut bar + draggable return button
- Chat page has draggable floating button to toggle between chat bubbles and terminal view
- Shell channel closes on return to chat mode; SSH connection stays alive

## Key providers
| Provider | Type | Purpose |
|----------|------|---------|
| `sshClientServiceProvider` | `Provider<SshClientService>` | singleton SSH service |
| `sshConnectionProvider` | `NotifierProvider<SshConnectionNotifier, SshConnectionState>` | connect/disconnect state machine |
| `chatProvider` | `NotifierProvider<ChatNotifier, ChatState>` | messages, sessions, input, directory |
| `transferProvider` | `NotifierProvider<TransferNotifier, TransferState>` | file transfer tracking |
| `isDarkModeProvider` | `NotifierProvider<..., bool>` | dark mode toggle |
| `downloadDirProvider` | `NotifierProvider<..., String>` | user-configured download path |

## Database tables
`hosts`, `sessions`, `chat_messages`, `transfer_tasks`, `quick_commands`

## Build environment
- Flutter 3.41.9 / Dart 3.11.5
- Android minSdk 34, targetSdk 35
- AGP 8.11.1, Gradle 8.14, Kotlin 2.2.20
- Android-only (no iOS platform files)

## Style notes
- Riverpod: `ref.read(provider.notifier)` for actions, `ref.watch(provider)` for reactive UI
- Material 3 with `colorSchemeSeed: Colors.blue`
- Code: Chinese comments and UI strings throughout
- SCP transfer uses `cat` for downloads (not raw SCP protocol on the download path)
- Password stored in plaintext in SQLite (security note)
