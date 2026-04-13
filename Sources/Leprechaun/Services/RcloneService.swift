import Foundation
@preconcurrency import os

/// Manages rclone subprocess execution for backup operations.
@MainActor
final class RcloneService {
    private static let logger = Logger(subsystem: "com.leprechaun", category: "Rclone")
    private var activeProcess: Process?
    private var progressHandler: ((RcloneProgress) -> Void)?

    /// Current progress of an active rclone operation.
    struct RcloneProgress {
        var percentage: Double?       // 0.0 - 1.0
        var speed: String?
        var eta: String?
        var transferredBytes: Int64?
        var totalBytes: Int64?
        var filesTransferred: Int?
        var rawStats: String?
    }

    /// Runs a backup operation using rclone.
    /// - Parameters:
    ///   - sourcePath: Local source directory path.
    ///   - destinationPath: Remote destination path (e.g., `/Volumes/NAS/backups/docs`).
    ///   - mode: `.copy` to only add/update, `.sync` to mirror (delete on remote).
    ///   - onProgress: Called periodically with progress updates.
    /// - Returns: The result of the operation.
    func run(
        sourcePath: String,
        destinationPath: String,
        mode: CopyMode,
        logFilePath: String,
        onProgress: (@MainActor (RcloneProgress) -> Void)? = nil
    ) async throws -> RcloneResult {
        guard let rclonePath = ResourceLocator.rclonePath else {
            throw RcloneError.binaryNotFound
        }

        self.progressHandler = onProgress

        let process = Process()
        process.executableURL = URL(fileURLWithPath: rclonePath)
        process.arguments = buildArguments(
            sourcePath: sourcePath,
            destinationPath: destinationPath,
            mode: mode,
            logFilePath: logFilePath
        )

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stdoutPipe // Merge stderr into stdout for parsing

        self.activeProcess = process

        Self.logger.info("Launching rclone: \(rclonePath) \(process.arguments?.joined(separator: " ") ?? "")")

        do {
            try process.run()
        } catch {
            self.activeProcess = nil
            throw RcloneError.processLaunchFailed(error)
        }

        // Read output asynchronously
        let outputTask = Task {
            var output = ""
            let fileHandle = stdoutPipe.fileHandleForReading
            do {
                for try await line in fileHandle.bytes.lines {
                    output += line + "\n"
                    if let progress = self.parseProgress(from: line) {
                        await MainActor.run {
                            onProgress?(progress)
                        }
                    }
                }
            } catch {
                // Stream ended
            }
            return output
        }

        // Wait for process to finish
        process.waitUntilExit()
        let fullOutput = await outputTask.value
        self.activeProcess = nil

        let result = RcloneResult(
            exitCode: Int(process.terminationStatus),
            output: fullOutput,
            duration: nil
        )

        if result.exitCode == 0 {
            Self.logger.info("Rclone completed successfully")
        } else {
            Self.logger.error("Rclone failed with exit code \(result.exitCode)")
            throw RcloneError.operationFailed(result)
        }

        return result
    }

    /// Cancels the currently running rclone process.
    func cancel() {
        guard let process = activeProcess, process.isRunning else {
            return
        }
        process.interrupt() // Sends SIGINT (graceful shutdown)
        Self.logger.info("Sent interrupt to rclone process")
    }

    // MARK: - Private

    private func buildArguments(
        sourcePath: String,
        destinationPath: String,
        mode: CopyMode,
        logFilePath: String
    ) -> [String] {
        let args = [
            mode.rawValue,  // "copy" or "sync"
            sourcePath,
            destinationPath,
            "--progress",
            "--stats", "1s",
            "--stats-log-level", "NOTICE",
            "--use-json-log",
            "--log-file", logFilePath,
            "--log-level", "INFO",
            "--retries", "3",
            "--retries-sleep", "5s",
        ]

        return args
    }

    /// Parses rclone progress output for status updates.
    private func parseProgress(from line: String) -> RcloneProgress? {
        // rclone with --use-json-log outputs JSON to stderr
        // We look for JSON objects containing transfer stats
        guard let data = line.data(using: .utf8) else { return nil }

        // Try to decode as JSON log entry
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let progress = parseJSONStats(json) {
                return progress
            }
        } catch {
            // Not JSON — try to parse text-based progress output
            return parseTextProgress(from: line)
        }

        return nil
    }

    private func parseJSONStats(_ json: [String: Any]) -> RcloneProgress? {
        // rclone JSON log format varies; look for common keys
        var progress = RcloneProgress()

        if let speed = json["speed"] as? Double {
            progress.speed = formatBytesPerSecond(speed)
        }
        if let eta = json["eta"] as? Double {
            progress.eta = formatSeconds(eta)
        }
        if let bytes = json["bytes"] as? Double {
            progress.transferredBytes = Int64(bytes)
        }
        if let totalBytes = json["totalBytes"] as? Double {
            progress.totalBytes = Int64(totalBytes)
        }
        if let totalBytes2 = json["total_bytes"] as? Double {
            progress.totalBytes = Int64(totalBytes2)
        }
        if let transferred = json["transferred"] as? Double {
            progress.transferredBytes = Int64(transferred)
        }
        if let pct = json["percent"] as? Double {
            progress.percentage = pct / 100.0
        }
        if let transfers = json["transfers"] as? Double {
            progress.filesTransferred = Int(transfers)
        }

        // If we got any stats, return it
        if progress.transferredBytes != nil || progress.speed != nil {
            return progress
        }
        return nil
    }

    private func parseTextProgress(from line: String) -> RcloneProgress? {
        // Text format examples:
        // "Transferred: 1.234 GiB / 5.678 GiB, 22%, 12.345 MiB/s, ETA 5m30s"
        // "Transferred: 100% / 100%, 0/s, ETA -"

        var progress = RcloneProgress()

        // Look for percentage
        if let range = line.range(of: #"(\d+)%"#, options: .regularExpression) {
            let pctStr = String(line[range]).replacingOccurrences(of: "%", with: "")
            if let pct = Double(pctStr) {
                progress.percentage = pct / 100.0
            }
        }

        progress.rawStats = line
        return progress.percentage != nil ? progress : nil
    }

    private func formatBytesPerSecond(_ bytes: Double) -> String {
        let units = ["B/s", "KiB/s", "MiB/s", "GiB/s"]
        var value = bytes
        var unitIndex = 0
        while value > 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    private func formatSeconds(_ seconds: Double) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes)m\(secs)s"
    }
}

// MARK: - Result & Errors

struct RcloneResult {
    let exitCode: Int
    let output: String
    let duration: TimeInterval?
}

enum RcloneError: LocalizedError {
    case binaryNotFound
    case processLaunchFailed(Error)
    case operationFailed(RcloneResult)
    case destinationNotFound
    case permissionDenied(String)
    case networkError(String)
    case mountFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "The backup engine (rclone) is missing from the app. Please reinstall the app."
        case .processLaunchFailed(let error):
            return "Could not start the backup engine: \(error.localizedDescription)"
        case .operationFailed(let result):
            return extractUserFriendlyError(from: result)
        case .destinationNotFound:
            return "The destination path does not exist. Check your backup settings."
        case .permissionDenied(let path):
            return "Permission denied for \"\(path)\". Check folder permissions in System Settings > Privacy & Security."
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .mountFailed(let detail):
            return "Could not mount the NAS: \(detail)"
        }
    }

    private func extractUserFriendlyError(from result: RcloneResult) -> String {
        let output = result.output.lowercased()

        // Common rclone error patterns
        if output.contains("no such file or directory") {
            return "Source or destination path not found. Check that the folder exists."
        }
        if output.contains("permission denied") || output.contains("access denied") {
            return "Permission denied. Check folder permissions in System Settings > Privacy & Security."
        }
        if output.contains("connection refused") || output.contains("network is unreachable") {
            return "Cannot reach the destination. Check your network connection and NAS is online."
        }
        if output.contains("mount") && output.contains("failed") {
            return "Failed to mount the NAS. Try mounting it manually in Finder."
        }
        if output.contains("i/o timeout") || output.contains("timeout") {
            return "Connection timed out. The NAS may be offline or unreachable."
        }

        // Fallback: show exit code
        return "The backup engine exited with code \(result.exitCode). View the log for details."
    }
}
