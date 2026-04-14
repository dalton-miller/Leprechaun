# Leprechaun

A simple macOS backup app that syncs folders to a NAS or cloud storage using [rclone](https://rclone.org).

## What it does

- **Backup folders** from your Mac to an SMB share (NAS), local path, or cloud storage
- **Schedule backups** — hourly, daily, weekly — powered by `launchd`
- **Copy or Mirror mode** — safe copy (never deletes) or full mirror (destination matches source exactly)
- **Auto-mounts SMB shares** — stores credentials in the Keychain
- **Menu bar status** — see what's running at a glance, trigger backups with one click
- **Notifications** — get alerted when a backup completes or fails

## What it doesn't do

- Replace a full backup solution like Time Machine (no versioning, no deduplication)
- Run without rclone (it's bundled in the app)

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (arm64) or Intel (x86_64)

## Installation

1. Download the latest `.dmg` from [Releases](https://github.com/dalton-miller/Leprechaun/releases)
2. Open the DMG and drag **Leprechaun** to your Applications folder
3. Open the app — the first time macOS may warn that the app can't be checked for malicious software:
   - Go to **System Settings > Privacy & Security** and click **Open Anyway**, or
   - Right-click the app and select **Open** (bypasses Gatekeeper for this one launch)
   - Or run: `xattr -cr /Applications/Leprechaun.app`

## Building from source

```bash
# Clone
git clone https://github.com/YOUR_USERNAME/leprechaun.git
cd leprechaun

# Build & run (debug)
make run

# Build release + DMG
make release

# Build release + sign + notarize (requires Developer ID)
make release-signed SIGN_IDENTITY='Developer ID Application: Your Name (TEAM)' TEAM_ID=YOUR_TEAM_ID
make release-notarized SIGN_IDENTITY='...' TEAM_ID=YOUR_TEAM_ID

# Clean everything
make clean
```

> rclone binaries are downloaded automatically during build from the official [rclone releases](https://github.com/rclone/rclone/releases) on GitHub. Nothing is committed to the repo.

## Architecture

```
Leprechaun (SwiftUI app)
  │
  ├── RcloneService    →  Spawns rclone subprocess, parses progress
  ├── VolumeMountService  →  SMB mount detection & mounting via mount_smbfs
  ├── KeychainService  →  Stores SMB credentials in the Keychain
  ├── SchedulerService  →  Generates launchd plists + shell wrapper
  ├── StorageService   →  JSON persistence in Application Support
  └── NotificationService  →  macOS user notifications
```

## Roadmap

See [todo.md](todo.md) for the current status of features.

## License

MIT. rclone is licensed under the MIT License — see [rclone.org](https://rclone.org).
