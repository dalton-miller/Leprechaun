import SwiftUI

struct LogView: View {
    let task: BackupTask
    @State private var logContent: String = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Log: \(task.name)")
                    .font(.headline)
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") {
                    loadLog()
                }
                .disabled(isLoading)
            }
            .padding()

            Divider()

            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if logContent.isEmpty {
                    Text("No log available yet.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    Text(logContent)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .onAppear { loadLog() }
    }

    private func loadLog() {
        isLoading = true
        let logPath = StorageService.logPath(for: task)
        let url = URL(filePath: logPath)

        if FileManager.default.fileExists(atPath: logPath) {
            do {
                logContent = try String(contentsOf: url)
            } catch {
                logContent = "Error reading log: \(error.localizedDescription)"
            }
        } else {
            logContent = ""
        }
        isLoading = false
    }
}
