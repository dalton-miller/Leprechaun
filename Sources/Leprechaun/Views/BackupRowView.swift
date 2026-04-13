import SwiftUI

struct BackupRowView: View {
    let task: BackupTask

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            statusIcon

            // Info column
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Text(task.sourceLastComponent)
                    Text("→")
                    Text(task.destinationLastComponent)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if task.status == .running {
                    transferInfo
                } else {
                    Text(scheduleDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Right column: status + actions
            VStack(spacing: 4) {
                lastRunInfo
                HStack(spacing: 4) {
                    if task.status == .running {
                        Button("Cancel", systemImage: "xmark.circle.fill") {
                            AppState.shared.cancelTask(task)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    } else {
                        Button("Run", systemImage: "play.fill") {
                            AppState.shared.runTask(task)
                        }
                        .buttonStyle(.borderless)
                    }
                    Button("Edit", systemImage: "pencil") {
                        AppState.shared.selectedTask = task
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(task.isEnabled ? 1.0 : 0.5)
        .overlay(alignment: .bottomTrailing) {
            if case .failed = task.status {
                Text("Right-click → View Log")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
        }
        .overlay(alignment: .bottom) {
            if task.status == .running {
                GeometryReader { geometry in
                    ProgressView(value: task.transferProgress)
                        .progressViewStyle(.linear)
                        .frame(height: 3)
                        .scaleEffect(x: 1, y: 0.7)
                        .position(x: geometry.size.width / 2, y: -1)
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Subviews

    private var statusIcon: some View {
        Group {
            switch task.status {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(task.isEnabled ? .green : .gray)
            case .running:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.title2)
    }

    private var lastRunInfo: some View {
        Group {
            if let lastRun = task.lastRun {
                Text(lastRun.timestamp.relativeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Never run")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var scheduleDescription: String {
        switch task.schedule {
        case .hourly:
            return "Every hour"
        case .daily(let hour, let minute):
            return "Daily at \(formatHour(hour)):\(String(format: "%02d", minute))"
        case .weekly(let day, let hour, let minute):
            let dayName = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][day]
            return "Weekly on \(dayName) at \(formatHour(hour)):\(String(format: "%02d", minute))"
        case .custom:
            return "Custom schedule"
        }
    }

    private var transferInfo: some View {
        HStack(spacing: 6) {
            Text("\(Int(task.transferProgress * 100))%")
            if !task.transferSpeed.isEmpty {
                Text("· \(task.transferSpeed)")
            }
            if !task.transferETA.isEmpty {
                Text("· \(task.transferETA)")
            }
        }
        .font(.caption)
        .foregroundStyle(.primary)
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 || hour == 12 {
            return "12"
        }
        return "\(hour % 12)"
    }
}

private extension String {
    var lastComponent: String {
        (self as NSString).lastPathComponent
    }
}

private extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
