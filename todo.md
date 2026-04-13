# Leprechaun — Todo

## Completed
- [x] Swift/SwiftUI app scaffold with SPM
- [x] BackupListView (main list, empty state)
- [x] BackupRowView (status, info, Run/Cancel/Edit buttons)
- [x] AddBackupView (source picker, destination, schedule, copy/sync toggle)
- [x] EditBackupView (edit all fields, last run info)
- [x] RcloneService (subprocess management, progress parsing)
- [x] KeychainService (SMB credential storage/retrieval)
- [x] VolumeMountService (SMB mount detection + mounting)
- [x] SchedulerService (launchd plist + wrapper script generation)
- [x] StorageService (JSON persistence)
- [x] Run/Cancel wired to RcloneService
- [x] MenuBarExtra (status icon, quick-run, settings, quit)
- [x] Log viewer (context menu → View Log)
- [x] Release build + DMG packaging (`./package.sh`)
- [x] Code signing + notarization pipeline
- [x] rclone binaries bundled (arm64 + x86_64)
- [x] Error UX (user-friendly error messages, alerts per error type)
- [x] macOS notifications on backup completion/failure
- [x] Auto-reset success status after 5 seconds
- [x] "View Log" hint overlay on failed tasks
- [x] Renamed project to Leprechaun

## Remaining
- [ ] App icon (SVG template created at `AppIcon.svg` — needs 16–1024px iconset for macOS)
- [ ] Wire SMB connection info through to launchd wrapper script
- [ ] "Next run" preview text on BackupRowView
- [ ] Backup encryption settings (rclone crypt remote)
- [ ] Test against real NAS/remote path
- [ ] Homebrew cask (optional, for easy updates)
- [ ] Codeberg CI for automated releases
- [ ] Sparkle framework for in-app updates
