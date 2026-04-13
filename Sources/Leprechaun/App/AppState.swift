import Foundation
import Observation

/// Shared application state holding the list of backup tasks.
@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    var tasks: [BackupTask]
    var isAddSheetPresented = false
    var selectedTask: BackupTask?
    var showLogForTask: BackupTask?

    /// Error alert state
    var showErrorAlert = false
    var currentErrorTitle: String = ""
    var currentErrorMessage: String = ""
    var failedTaskForError: BackupTask?

    private let rcloneService = RcloneService()
    private var runningTasks: [UUID: Task<Void, Never>] = [:]

    private init() {
        self.tasks = StorageService.loadTasks()
    }

    func save() {
        StorageService.saveTasks(tasks)
        SchedulerService.syncAgents(with: tasks)
    }

    func addTask(_ task: BackupTask) {
        tasks.append(task)
        save()
    }

    func updateTask(_ task: BackupTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            save()
        }
    }

    func deleteTask(_ task: BackupTask) {
        cancelTask(task)
        tasks.removeAll { $0.id == task.id }
        save()
    }

    // MARK: - Backup Execution

    func runTask(_ task: BackupTask) {
        guard task.status != .running else { return }

        task.status = .running
        task.transferProgress = 0
        task.transferSpeed = ""
        task.transferETA = ""
        task.lastRun = LastRunInfo(timestamp: Date())

        let taskID = task.id
        let sourcePath = task.sourcePath
        let destinationPath = task.destinationPath
        let copyMode = task.copyMode
        let logFilePath = StorageService.logPath(for: task)
        let startTime = Date()

        let work = Task.detached {
            do {
                _ = try await self.rcloneService.run(
                    sourcePath: sourcePath,
                    destinationPath: destinationPath,
                    mode: copyMode,
                    logFilePath: logFilePath
                ) { progress in
                    self.updateProgress(taskID: taskID, progress: progress)
                }

                await MainActor.run {
                    self.finishTask(taskID: taskID, startTime: startTime, error: nil)
                }
            } catch {
                await MainActor.run {
                    self.finishTask(taskID: taskID, startTime: startTime, error: error.localizedDescription)
                }
            }
        }

        runningTasks[task.id] = work
    }

    private func updateProgress(taskID: UUID, progress: RcloneService.RcloneProgress) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        if let pct = progress.percentage {
            task.transferProgress = min(pct, 1.0)
        }
        task.transferSpeed = progress.speed ?? ""
        task.transferETA = progress.eta ?? ""
    }

    private func finishTask(taskID: UUID, startTime: Date, error: String?) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        let duration = Date().timeIntervalSince(startTime)
        task.lastRun = LastRunInfo(
            timestamp: Date(),
            duration: duration,
            error: error
        )

        if let error {
            task.status = .failed(error)
            currentErrorTitle = "Backup Failed"
            currentErrorMessage = "\"\(task.name)\" failed:\n\n\(error)"
            failedTaskForError = task
            showErrorAlert = true
            NotificationService.postFailure(for: task.name, error: error)
        } else {
            task.status = .success
            NotificationService.postSuccess(for: task.name)
            // Auto-reset to idle after 5 seconds
            let taskID = taskID
            Task {
                try await Task.sleep(for: .seconds(5))
                await MainActor.run {
                    if self.tasks.first(where: { $0.id == taskID })?.status == .success {
                        self.tasks.first(where: { $0.id == taskID })?.status = .idle
                    }
                }
            }
        }

        runningTasks[taskID] = nil
        save()
    }

    func cancelTask(_ task: BackupTask) {
        guard task.status == .running else { return }
        rcloneService.cancel()
        runningTasks[task.id]?.cancel()
        runningTasks[task.id] = nil
        task.status = .idle
        task.transferProgress = 0
        task.transferSpeed = ""
        task.transferETA = ""
    }
}
