import SwiftUI
import AppKit

@main
struct LeprechaunApp: App {
    @State private var appState: AppState

    init() {
        _appState = State(initialValue: AppState.shared)
    }

    var body: some Scene {
        WindowGroup {
            BackupListView()
                .frame(minWidth: 500, minHeight: 300)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 550, height: 400)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            MenuBarContentView()
        } label: {
            Image(systemName: appState.tasks.contains(where: { $0.status == .running })
                ? "arrow.triangle.2.circlepath"
                : "externaldrive.fill.badge.icloud")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .frame(width: 450, height: 400)
        }
    }
}

/// Content shown in the menu bar extra dropdown.
struct MenuBarContentView: View {
    var body: some View {
        Group {
            // Running tasks
            ForEach(AppState.shared.tasks.filter({ $0.status == .running })) { task in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolEffect(.variableColor.iterative.dimInactiveLayers)
                        Text(task.name)
                            .font(.caption)
                        Spacer()
                        Text("\(Int(task.transferProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !task.transferSpeed.isEmpty {
                        Text("\(task.transferSpeed) · \(task.transferETA)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if AppState.shared.tasks.contains(where: { $0.status == .running }) {
                Divider()
            }

            // Quick actions per task
            ForEach(AppState.shared.tasks) { task in
                Button {
                    AppState.shared.runTask(task)
                } label: {
                    Label("Run \"\(task.name)\"", systemImage: "play.fill")
                }
            }

            if !AppState.shared.tasks.isEmpty {
                Divider()
            }

            Button("Open App") {
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Button("Quit", role: .cancel) {
                NSApp.terminate(nil)
            }
        }
    }
}
