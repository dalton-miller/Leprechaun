import SwiftUI

struct EditBackupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appState: AppState

    @Bindable var task: BackupTask

    @State private var name: String
    @State private var sourcePath: String
    @State private var destinationPath: String
    @State private var schedule: Schedule
    @State private var copyMode: CopyMode
    @State private var isEnabled: Bool

    @State private var isShowingSourcePicker = false

    init(task: BackupTask) {
        _appState = State(initialValue: AppState.shared)
        self.task = task
        _name = State(initialValue: task.name)
        _sourcePath = State(initialValue: task.sourcePath)
        _destinationPath = State(initialValue: task.destinationPath)
        _schedule = State(initialValue: task.schedule)
        _copyMode = State(initialValue: task.copyMode)
        _isEnabled = State(initialValue: task.isEnabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Backup name", text: $name)
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
                    TextField("Destination path", text: $destinationPath)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Schedule") {
                    Toggle("Enabled", isOn: $isEnabled)
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

                    if copyMode == .sync {
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(copyMode.description)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                Section("Last Run") {
                    if let lastRun = task.lastRun {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Time: \(lastRun.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            if let duration = lastRun.duration {
                                Text("Duration: \(duration.formatted())")
                            }
                            if let files = lastRun.filesTransferred {
                                Text("Files: \(files)")
                            }
                            if let error = lastRun.error {
                                Text("Error: \(error)")
                                    .foregroundStyle(.red)
                            }
                        }
                        .font(.caption)
                    } else {
                        Text("Never run")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Backup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
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

    @MainActor
    private func save() {
        task.name = name
        task.sourcePath = sourcePath
        task.destinationPath = destinationPath
        task.schedule = schedule
        task.copyMode = copyMode
        task.isEnabled = isEnabled
        appState.updateTask(task)
        dismiss()
    }
}
