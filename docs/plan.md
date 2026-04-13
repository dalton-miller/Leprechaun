# Backup App — Project Plan

## Overview
A native macOS app that simplifies folder-to-remote (e.g., NAS) backups using rclone's functionality, with scheduling and a minimal, user-friendly UI.

---

## Architecture Decision: Subprocess Over Library

**We will call rclone as a subprocess, NOT embed it as a library.**

Rationale:
- Embedding rclone adds **271+ dependencies** (AWS SDK, GCP SDK, Azure SDK, etc.), drastically bloating binary size
- rclone's library API is not designed for first-class embedding; `librclone` is marked experimental
- Global state (`fs.Config`) makes concurrent usage difficult
- CLI interface is stable and well-documented
- Easier to update rclone independently
- Simpler debugging and error handling via exit codes/stdout/stderr

The app bundles a precompiled rclone binary and manages it as a subprocess.

---

## Tech Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| UI (native macOS) | SwiftUI + AppKit (if needed) | macOS 14+ target, declarative, native look |
| Scheduling | `launchd` (user-level LaunchAgents) | Survives app termination, the macOS standard |
| rclone execution | Bundled rclone binary as subprocess | Detect arch (arm64/x86_64), bundle both |
| IPC | stdio (stdout/stderr parsing) | Simple, no network stack needed |
| Future cross-platform | Tauri 2 (recommended) | Sidecar support for Go/rclone binary, small binaries |

---

## Core Features (MVP)

### 1. Backup Configuration
- **Source folder picker** — native macOS folder selector
- **Destination** — remote path in rclone syntax (e.g., `mynas:/backups/myfolder`)
- **Remote setup** — minimal wizard to configure an rclone remote (SMB, S3, etc.)
- **Backup name** — user-friendly label for each backup task

### 2. Scheduling
- **Simple frequency selector**: Hourly / Daily / Weekly / Custom
- **Next run preview** — show when the next backup will occur
- **Enable/disable toggle** — quick on/off per backup task
- **Behind the scenes**: install/update `launchd` plist in `~/Library/LaunchAgents/`

### 3. Status & History
- **Current status** — Idle / Running / Failed (per task)
- **Last run info** — timestamp, duration, files transferred, errors
- **Log viewer** — simple scrollable log per backup task

### 4. Manual Controls
- **Run now** — trigger a backup immediately
- **Cancel** — stop a running backup
- **Edit** — modify source, destination, or schedule

---

## UI Design Principles

### Keep It Simple
The UI should fit in a single window with minimal chrome:

```
┌─────────────────────────────────────────────┐
│  BackupThing                           [⚙️] │
├─────────────────────────────────────────────┤
│                                             │
│  📁 My Documents → mynas:/backups/docs      │
│     Daily at 2:00 AM  •  Last: 3h ago  ✅   │
│                        [Run Now] [Edit]     │
│                                             │
│  📁 Photos → mynas:/backups/photos          │
│     Weekly on Sunday  •  Last: 2d ago  ✅    │
│                        [Run Now] [Edit]     │
│                                             │
│  📁 Projects → mynas:/backups/projects      │
│     Hourly  •  Running...  ⏳  [Cancel]     │
│                                             │
│  ─────────────────────────────────────────  │
│  [+ Add Backup]                             │
│                                             │
└─────────────────────────────────────────────┘
```

- **No tabs, no nested navigation** — everything visible at a glance
- **Settings** (gear icon): rclone remote management, notifications, advanced rclone flags
- **Menu bar presence** — `MenuBarExtra` showing quick status + "Show App" option
- **Color coding**: green = success, red = error, blue = running

---

## Project Structure

```
backupthing/
├── BackupThing/             # SwiftUI app (Xcode project)
│   ├── App/
│   │   └── BackupThingApp.swift
│   ├── Views/
│   │   ├── BackupListView.swift       # Main view
│   │   ├── BackupRowView.swift        # Single backup row
│   │   ├── AddBackupView.swift        # Sheet for new backup
│   │   ├── EditBackupView.swift       # Edit existing backup
│   │   ├── LogView.swift              # Log viewer
│   │   └── SettingsView.swift         # Remote config, advanced
│   ├── Models/
│   │   ├── BackupTask.swift           # Data model (Observable)
│   │   └── BackupHistoryEntry.swift
│   ├── Services/
│   │   ├── RcloneService.swift         # Subprocess management
│   │   ├── VolumeMountService.swift    # SMB mount detection + mounting
│   │   ├── SchedulerService.swift      # launchd plist management
│   │   ├── KeychainService.swift       # Credential storage
│   │   └── StorageService.swift        # Persistence (SwiftData or UserDefaults)
│   └── Resources/
│       ├── rclone-darwin-arm64
│       └── rclone-darwin-x86_64
│
├── Shared/                    # Shared types (if needed later for cross-platform)
│
└── docs/
    └── plan.md               # This file
```

---

## Implementation Phases

### Phase 1: Foundation
- [ ] Set up Xcode project with SwiftUI
- [ ] Create `BackupTask` model + `Observable` state
- [ ] Implement `RcloneService` (subprocess spawn, stdio parsing, cancellation)
- [ ] Bundle rclone binaries (arm64 + x86_64), detect at runtime
- [ ] Implement `VolumeMountService` (native SMB mount via DiskArbitration / `mount_smbfs`)
- [ ] Basic `BackupListView` showing hardcoded tasks

### Phase 2: Core Functionality
- [ ] `AddBackupView` — source picker, destination input, remote setup wizard
- [ ] `RcloneService.sync()` — wire up actual rclone `sync` / `copy` commands
- [ ] Progress parsing from rclone's `--progress` / `--stats` output
- [ ] `BackupRowView` with live status updates
- [ ] Persistence layer (SwiftData or file-based JSON)

### Phase 3: Scheduling
- [ ] `SchedulerService` — generate and manage `launchd` plists
- [ ] Install/uninstall LaunchAgents at `~/Library/LaunchAgents/com.backupthing.task.<uuid>.plist`
- [ ] Frequency selector UI (Hourly / Daily / Weekly / Custom)
- [ ] Next-run preview calculation
- [ ] Enable/disable toggle → bootstrap/Bootout LaunchAgent

### Phase 4: Polish
- [ ] Log viewer per backup task
- [ ] History tracking (last run time, duration, file count, errors)
- [ ] `MenuBarExtra` for quick status
- [ ] Error handling + user-friendly error messages
- [ ] Notifications on backup completion/failure
- [ ] Settings view for remote management (`rclone config` integration)

### Phase 5: Testing & Release
- [ ] Unit tests for `SchedulerService` (plist generation)
- [ ] Integration tests for `RcloneService` (mock rclone or test against local dir)
- [ ] Manual testing on both Apple Silicon and Intel Macs
- [ ] Code signing + notarization setup
- [ ] App packaging (DMG or direct download)

---

## Key Technical Details

### Rclone Subprocess Management
```
rclone copy "<source>" "<remote>:<dest>" \
  --progress \
  --stats=1s \
  --stats-log-level=NOTICE \
  --log-file=<path-to-log> \
  --log-level=INFO
```
- Parse stdout for progress stats (rclone outputs JSON with `--use-json-log`)
- Cancel via `Process.interrupt()` or sending SIGINT
- Exit code 0 = success, non-zero = failure

### launchd Plist Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.backupthing.task.{UUID}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/path/to/app/Contents/Resources/rclone-wrapper.sh</string>
    <string>{BACKUP_TASK JSON}</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>2</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/path/to/logs/{UUID}.out</string>
  <key>StandardErrorPath</key>
  <string>/path/to/logs/{UUID}.err</string>
</dict>
</plist>
```

### Data Persistence
- **SwiftData** (macOS 14+) for structured data, or
- **JSON file** in `~/Library/Application Support/BackupThing/tasks.json` for simplicity
- Store: task ID, name, source, destination, schedule config, enabled state, last run info

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| rclone binary changes flags/behavior | Pin to a specific rclone version, test updates before bumping |
| launchd jobs fail due to sandbox | Use hardened runtime without sandbox; DMG distribution avoids MAS restrictions |
| NAS unreachable at backup time | Shell wrapper retries mount (30s timeout), rclone retries (`--retries 3`), notification on failure |
| Cross-platform later | Tauri 2 sidecar for rclone; keep shell wrapper portable |
| SMB credentials exposure | Store in Keychain only; read back via Security framework, never log or persist plaintext |

---

## Resolved Decisions

### Sync vs Copy
- **Default to `rclone copy`** (only adds/updates, never deletes on remote)
- Expose a **"Mirror mode" toggle** during backup setup that switches to `rclone sync`
- Include a clear warning explaining that sync will delete remote files not present in source

### Remote Type (Phase 1)
- **SMB/NAS first** — use native macOS APIs to mount the SMB volume (same as Finder)
- If the volume isn't already mounted, mount it automatically before running rclone
- Use `mount_smbfs` or DiskArbitration framework for native mounting behavior

### Encryption
- Offer rclone's **crypt remote** as an advanced feature in Settings
- Keep it out of the initial Add Backup flow to preserve simplicity

### Distribution
- **Direct DMG download** hosted on Codeberg
- No Mac App Store constraints — means fewer sandbox restrictions
- Code signing + notarization still required for Gatekeeper

### SMB Mount Credentials
- **Store in macOS Keychain** for security
- If credentials aren't found, **prompt the user to mount the share in Finder first** — let Finder handle credential entry and Keychain storage, then we read them back
- Falls back to asking for username/password directly if the user prefers

### launchd Wrapper
- Use a **shell script wrapper** that launchd invokes
- The wrapper handles: mount check → mount if needed → run rclone → log output
- More robust than calling rclone directly (can handle mount failures, retries)

### Mount Timeout
- **30 seconds** — wait up to 30s for SMB mount to complete before failing the backup

## Next Steps

1. Download rclone binaries for darwin-arm64 and darwin-x86_64
2. Create Xcode project and scaffold the SwiftUI app
3. Implement `KeychainService` (store/retrieve SMB credentials)
4. Implement `VolumeMountService` (SMB mount detection + mounting)
5. Implement `RcloneService` with a basic copy command
6. Build the `BackupListView` with hardcoded data
7. Wire up the Add Backup flow with copy/sync toggle
8. Implement launchd wrapper script + `SchedulerService`
