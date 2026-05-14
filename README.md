# SSH Client

An Android SSH client built with Flutter, featuring session management, file transfer via SCP, LAN scanning, and interactive command execution.

## Features

- **SSH Connection** — Connect to remote hosts via password authentication, with session persistence
- **Command Execution** — Interactive command shell with directory tracking (`cd` wrapper + `pwd` parsing)
- **Directory Browser** — Top path bar shows current directory, click to list subdirectories via `ls -la`
- **File Transfer (SCP)** — Upload/download files through the SSH connection
- **Session Management** — Keep sessions alive when leaving chat page, reconnect seamlessly
- **History** — Per-session history with messages, search, and replay
- **LAN Scanner** — Batch TCP port scanner (100 IPs/batch, 3s interval) with pause/resume/stop
- **Quick Commands** — Customizable command chips with add/edit/delete/reorder via manage panel
- **Host Management** — Saved hosts with edit/delete, connection status indicators
- **Theme** — Dark mode toggle, Material3 design

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.41.9 |
| Language | Dart 3.11.5 |
| SSH | dartssh2 2.17.1 |
| State Management | Riverpod 2.6.1 |
| Database | SQLite (sqlite3) |
| Min Android API | 34 |
| Target Android API | 35 |

## Architecture

```
Home Page (host list + LAN scan)
  └── Chat Page
       ├── Path Bar (directory browser)
       ├── Message List
       │    ├── Command (right-aligned)
       │    ├── Output (left-aligned)
       │    ├── System (centered)
       │    └── File Transfer (TransferBubble)
       ├── Quick Command Chips (customizable)
       ├── File Panel (upload/download)
       └── Input Bar
```

**Command Execution Engine:**
Every command is wrapped as `cd "<current_pwd>" && <command> && pwd`. The last line of output is parsed as the new working directory; everything else is displayed as command output.

**Session Lifecycle:**
- Sessions are tracked by unique ID (generated from host info + timestamp)
- Active sessions persist in memory; leaving the chat page with "keep session" preserves them
- Disconnecting sets `endTime` and moves the session to history
- Re-entering a kept session restores the last working directory via `cd "$lastDir" && pwd`

## Database Tables

| Table | Purpose |
|-------|---------|
| `hosts` | Saved SSH hosts with credentials |
| `sessions` | Connection sessions with timing |
| `chat_messages` | Command/output/system messages |
| `transfer_tasks` | File transfer records |
| `quick_commands` | User-customizable command shortcuts |

## Security Notes

- SSH passwords are stored in SQLite; no encryption at rest (device-level encryption recommended)
- No API keys, tokens, or certificates are bundled
- The app uses Android's Storage Access Framework (SAF) for file downloads on Android 14+
- **Release builds** currently use the default debug keystore — configure a release keystore via `android/key.properties` before distribution

## Building

```bash
flutter build apk --release
```
