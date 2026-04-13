import SwiftUI

struct BackupListView: View {
    @State private var appState: AppState

    init() {
        _appState = State(initialValue: AppState.shared)
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.tasks.isEmpty {
                emptyState
            } else {
                taskList
            }

            Divider()

            HStack {
                Button(action: {
                    appState.isAddSheetPresented = true
                }) {
                    Label("Add Backup", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $appState.isAddSheetPresented) {
            AddBackupView()
                .frame(width: 420, height: 480)
        }
        .sheet(item: $appState.showLogForTask) { task in
            LogView(task: task)
                .frame(width: 550, height: 400)
        }
        .alert(appState.currentErrorTitle, isPresented: $appState.showErrorAlert) {
            if appState.failedTaskForError != nil {
                Button("View Log") {
                    appState.showLogForTask = appState.failedTaskForError
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.currentErrorMessage)
        }
        .task {
            await NotificationService.requestAuthorization()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.fill.badge.icloud")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No backups configured")
                .font(.title2)

            Text("Add your first backup to get started.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var taskList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(appState.tasks) { task in
                    BackupRowView(task: task)
                        .contextMenu {
                            Button("Edit") {
                                appState.selectedTask = task
                            }
                            Button("Run Now", systemImage: "play.fill") {
                                appState.runTask(task)
                            }
                            Button("View Log", systemImage: "doc.text") {
                                appState.showLogForTask = task
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                appState.deleteTask(task)
                            }
                        }
                }
            }
            .padding()
        }
        .sheet(item: $appState.selectedTask) { task in
            EditBackupView(task: task)
                .frame(width: 420, height: 480)
        }
        .sheet(item: $appState.showLogForTask) { task in
            LogView(task: task)
                .frame(width: 550, height: 400)
        }
    }

    private func runTask(_ task: BackupTask) {
        appState.runTask(task)
    }
}
