import Foundation

@preconcurrency import os

/// Persists and loads backup task configurations.
@MainActor
enum StorageService {
    private static let logger = Logger(subsystem: "com.leprechaun", category: "Storage")

    /// Directory where backup task data is stored.
    static var dataDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appending(path: "Leprechaun")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Directory where rclone log files are stored.
    static var logDirectory: URL {
        let dir = dataDirectory.appending(path: "logs")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Path to the tasks JSON file.
    private static var tasksFileURL: URL {
        dataDirectory.appending(path: "tasks.json")
    }

    // MARK: - Save

    static func saveTasks(_ tasks: [BackupTask]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(tasks)
            try data.write(to: tasksFileURL, options: .atomicWrite)
            logger.info("Saved \(tasks.count) backup task(s)")
        } catch {
            logger.error("Failed to save tasks: \(error.localizedDescription)")
        }
    }

    // MARK: - Load

    static func loadTasks() -> [BackupTask] {
        guard FileManager.default.fileExists(atPath: tasksFileURL.path) else {
            logger.info("No saved tasks found")
            return []
        }

        do {
            let data = try Data(contentsOf: tasksFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tasks = try decoder.decode([BackupTask].self, from: data)
            logger.info("Loaded \(tasks.count) backup task(s)")
            return tasks
        } catch {
            logger.error("Failed to load tasks: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Log Path

    /// Returns the log file path for a given backup task.
    static func logPath(for task: BackupTask) -> String {
        logDirectory.appending(path: "\(task.id.uuidString).log").path
    }
}
