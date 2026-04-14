import Foundation

@preconcurrency import os

/// Manages launchd LaunchAgents for scheduled backup tasks.
@MainActor
enum SchedulerService {
    private static let logger = Logger(subsystem: "com.leprechaun", category: "Scheduler")

    /// The directory where user LaunchAgents are stored.
    static var launchAgentsDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appending(path: "Library/LaunchAgents")
    }

    /// The path to the bundled rclone binary.
    /// This will be resolved at runtime.
    static func rclonePath() -> String {
        ResourceLocator.rclonePath ?? "/usr/local/bin/rclone"
    }

    /// The path to the wrapper script within the app bundle.
    static func wrapperScriptPath() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appending(path: "Library/Application Support/Leprechaun")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appending(path: "backup-wrapper.sh")
    }

    // MARK: - Wrapper Script

    /// Installs the backup wrapper script at a known location.
    static func installWrapperScript() {
        let scriptURL = wrapperScriptPath()

        let script = """
        #!/bin/bash
        # Leprechaun launchd wrapper script
        # Called by launchd to run a scheduled backup.
        #
        # Arguments (passed via ProgramArguments in the plist):
        #   $1 = Source path
        #   $2 = Destination path
        #   $3 = Mode (copy or sync)
        #   $4 = Log file path

        SOURCE="$1"
        DEST="$2"
        MODE="$3"
        LOGFILE="$4"

        echo "$(date): Starting backup ($MODE): $SOURCE -> $DEST" >> "$LOGFILE"

        # Check that the destination path exists (volume should be mounted)
        if [ ! -d "$DEST" ]; then
            echo "$(date): Destination does not exist: $DEST" >> "$LOGFILE"
            echo "  Make sure the destination volume is mounted (e.g. via Login Items)." >> "$LOGFILE"
            exit 1
        fi

        # Run rclone
        RCLONE_PATH="{RCLONE_PATH_PLACEHOLDER}"
        "$RCLONE_PATH" "$MODE" "$SOURCE" "$DEST" \\
            --progress \\
            --stats 1s \\
            --stats-log-level NOTICE \\
            --log-file "$LOGFILE" \\
            --log-level INFO \\
            --retries 3 \\
            --retries-sleep 5s \\
            2>&1 | tee -a "$LOGFILE"

        EXIT_CODE=${PIPESTATUS[0]}
        echo "$(date): rclone exited with code $EXIT_CODE" >> "$LOGFILE"

        exit $EXIT_CODE
        """

        let resolvedScript = script.replacingOccurrences(
            of: "{RCLONE_PATH_PLACEHOLDER}",
            with: rclonePath()
        )

        do {
            try resolvedScript.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )
            logger.info("Wrapper script installed at \(scriptURL.path)")
        } catch {
            logger.error("Failed to install wrapper script: \(error.localizedDescription)")
        }
    }

    // MARK: - LaunchAgent Management

    /// Returns the plist path for a given backup task.
    static func plistPath(for task: BackupTask) -> URL {
        launchAgentsDirectory.appending(path: "com.leprechaun.task.\(task.id.uuidString).plist")
    }

    /// Installs (or updates) a LaunchAgent for a backup task.
    static func installLaunchAgent(for task: BackupTask) {
        installWrapperScript()

        let plistURL = plistPath(for: task)
        let scheduleDict = scheduleDict(from: task.schedule)

        let plist: [String: Any] = [
            "Label": "com.leprechaun.task.\(task.id.uuidString)",
            "ProgramArguments": [
                wrapperScriptPath().path,
                task.sourcePath,
                task.destinationPath,
                task.copyMode.rawValue,
                StorageService.logPath(for: task),
            ],
            "StartCalendarInterval": scheduleDict,
            "StandardOutPath": StorageService.logDirectory.appending(path: "\(task.id.uuidString).out").path,
            "StandardErrorPath": StorageService.logDirectory.appending(path: "\(task.id.uuidString).err").path,
            "RunAtLoad": false,
        ]

        let plistData = try? PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        do {
            try plistData?.write(to: plistURL, options: .atomic)
            logger.info("LaunchAgent plist written to \(plistURL.path)")

            // Bootstrap the agent
            bootstrapAgent(at: plistURL)
        } catch {
            logger.error("Failed to write LaunchAgent: \(error.localizedDescription)")
        }
    }

    /// Removes a LaunchAgent for a backup task.
    static func removeLaunchAgent(for task: BackupTask) {
        let plistURL = plistPath(for: task)

        // Bootout first if loaded
        bootoutAgent(label: "com.leprechaun.task.\(task.id.uuidString)")

        // Remove plist
        try? FileManager.default.removeItem(at: plistURL)
        logger.info("Removed LaunchAgent for task \(task.id)")
    }

    /// Updates all LaunchAgents based on current task list.
    static func syncAgents(with tasks: [BackupTask]) {
        // Remove agents for tasks that no longer exist or are disabled
        let currentIDs = Set(tasks.filter(\.isEnabled).map(\.id))
        let agentFiles = (try? FileManager.default.contentsOfDirectory(
            at: launchAgentsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []

        for file in agentFiles where file.lastPathComponent.hasPrefix("com.leprechaun.task.") {
            // Extract UUID from filename
            let name = file.deletingPathExtension().lastPathComponent
            let idStr = name.replacingOccurrences(of: "com.leprechaun.task.", with: "")
            if let uuid = UUID(uuidString: idStr), !currentIDs.contains(uuid) {
                bootoutAgent(label: name)
                try? FileManager.default.removeItem(at: file)
            }
        }

        // Install/update agents for enabled tasks
        for task in tasks where task.isEnabled {
            installLaunchAgent(for: task)
        }
    }

    // MARK: - Private

    private static func bootstrapAgent(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootstrap", "gui/\(currentUserUID())", url.path]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                logger.info("Bootstrapped LaunchAgent")
            } else {
                logger.warning("Bootstrap returned code \(process.terminationStatus)")
            }
        } catch {
            logger.error("Failed to bootstrap: \(error.localizedDescription)")
        }
    }

    private static func bootoutAgent(label: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(currentUserUID())/\(label)"]
        try? process.run()
        process.waitUntilExit()
    }

    private static func currentUserUID() -> UInt32 {
        getpwuid(getuid()).pointee.pw_uid
    }

    /// Converts a Schedule enum value to a launchd StartCalendarInterval dictionary.
    private static func scheduleDict(from schedule: Schedule) -> [String: Any] {
        switch schedule {
        case .hourly:
            return ["Minute": 0]  // Every hour at minute 0
        case .daily(let hour, let minute):
            return ["Hour": hour, "Minute": minute]
        case .weekly(let day, let hour, let minute):
            return ["Weekday": day, "Hour": hour, "Minute": minute]
        case .custom:
            // launchd doesn't support cron expressions natively;
            // fall back to daily as a safe default
            return ["Hour": 2, "Minute": 0]
        }
    }
}
