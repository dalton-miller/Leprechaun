import SwiftUI

struct AddBackupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appState: AppState

    init() {
        _appState = State(initialValue: AppState.shared)
    }

    @State private var name: String = ""
    @State private var sourcePath: String = ""
    @State private var destinationPath: String = ""
    @State private var schedule: Schedule = .daily(hour: 2, minute: 0)
    @State private var copyMode: CopyMode = .copy
    @State private var useMirrorWarningAcknowledged = false

    @State private var isShowingSourcePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Backup name (e.g. Documents)", text: $name)
                }

                Section("Source") {
                    HStack {
                        TextField("Folder path", text: $sourcePath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse…") {
                            isShowingSourcePicker = true
                        }
                    }
                }

                Section("Destination") {
                    TextField("Destination path (e.g. /Volumes/NAS/backups/docs)", text: $destinationPath)
                        .textFieldStyle(.roundedBorder)
                    Text("Use a mounted SMB volume or local path.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Schedule") {
                    Picker("Frequency", selection: scheduleBinding) {
                        Text("Hourly").tag(0)
                        Text("Daily").tag(1)
                        Text("Weekly").tag(2)
                    }
                    .pickerStyle(.segmented)

                    if let dailyBinding = dailyTimeBinding {
                        DatePicker("Time", selection: dailyBinding)
                            .datePickerStyle(.compact)
                    }

                    if let weeklyDayBinding = weeklyDayBinding {
                        Picker("Day", selection: weeklyDayBinding) {
                            ForEach(0..<7, id: \.self) { day in
                                Text(weekdays[day])
                            }
                        }
                    }
                }

                Section("Mode") {
                    Picker("Copy mode", selection: $copyMode) {
                        ForEach(CopyMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: copyMode == .sync ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .foregroundStyle(copyMode == .sync ? .red : .secondary)
                        Text(copyMode.description)
                            .font(.caption)
                            .foregroundStyle(copyMode == .sync ? .red : .secondary)
                    }
                    .padding(8)
                    .background(copyMode == .sync ? Color.red.opacity(0.08) : Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Backup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addBackup()
                    }
                    .disabled(!isValid)
                }
            }
            .fileImporter(
                isPresented: $isShowingSourcePicker,
                allowedContentTypes: [.directory],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    sourcePath = url.path
                }
            }
        }
    }

    // MARK: - Computed

    private var isValid: Bool {
        !name.isEmpty && !sourcePath.isEmpty && !destinationPath.isEmpty
    }

    private var weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    // Schedule bindings
    private var scheduleBinding: Binding<Int> {
        Binding(
            get: {
                switch schedule {
                case .hourly: return 0
                case .daily: return 1
                case .weekly: return 2
                case .custom: return 1
                }
            },
            set: { newValue in
                switch newValue {
                case 0: schedule = .hourly
                case 1: schedule = .daily(hour: 2, minute: 0)
                case 2: schedule = .weekly(day: 0, hour: 3, minute: 0)
                default: schedule = .daily(hour: 2, minute: 0)
                }
            }
        )
    }

    private var dailyTimeBinding: Binding<Date>? {
        guard case .daily(let hour, let minute) = schedule else { return nil }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return Binding(
            get: { date },
            set: { newDate in
                let cal = Calendar.current
                schedule = .daily(
                    hour: cal.component(.hour, from: newDate),
                    minute: cal.component(.minute, from: newDate)
                )
            }
        )
    }

    private var weeklyDayBinding: Binding<Int>? {
        guard case .weekly(let day, let hour, let minute) = schedule else { return nil }
        return Binding(
            get: { day },
            set: { newDay in
                schedule = .weekly(day: newDay, hour: hour, minute: minute)
            }
        )
    }

    // MARK: - Actions

    private func addBackup() {
        let task = BackupTask(
            name: name,
            sourcePath: sourcePath,
            destinationPath: destinationPath,
            schedule: schedule,
            copyMode: copyMode
        )
        appState.addTask(task)
        dismiss()
    }
}
