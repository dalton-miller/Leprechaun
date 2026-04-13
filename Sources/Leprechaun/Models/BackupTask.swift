import Foundation
import Observation

@Observable
class BackupTask: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var sourcePath: String
    var destinationPath: String
    var schedule: Schedule
    var isEnabled: Bool
    var copyMode: CopyMode
    var status: Status
    var lastRun: LastRunInfo?

    /// Live progress during a running backup (not persisted).
    @ObservationIgnored var transferProgress: Double = 0.0
    @ObservationIgnored var transferSpeed: String = ""
    @ObservationIgnored var transferETA: String = ""

    init(
        id: UUID = UUID(),
        name: String = "",
        sourcePath: String = "",
        destinationPath: String = "",
        schedule: Schedule = .daily(hour: 2, minute: 0),
        isEnabled: Bool = true,
        copyMode: CopyMode = .copy,
        status: Status = .idle,
        lastRun: LastRunInfo? = nil
    ) {
        self.id = id
        self.name = name
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.copyMode = copyMode
        self.status = status
        self.lastRun = lastRun
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, sourcePath, destinationPath, schedule, isEnabled, copyMode, status, lastRun
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.sourcePath = try container.decode(String.self, forKey: .sourcePath)
        self.destinationPath = try container.decode(String.self, forKey: .destinationPath)
        self.schedule = try container.decode(Schedule.self, forKey: .schedule)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.copyMode = try container.decode(CopyMode.self, forKey: .copyMode)
        self.status = try container.decode(Status.self, forKey: .status)
        self.lastRun = try container.decodeIfPresent(LastRunInfo.self, forKey: .lastRun)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sourcePath, forKey: .sourcePath)
        try container.encode(destinationPath, forKey: .destinationPath)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(copyMode, forKey: .copyMode)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(lastRun, forKey: .lastRun)
    }

    static func == (lhs: BackupTask, rhs: BackupTask) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Computed

    var sourceLastComponent: String {
        (sourcePath as NSString).lastPathComponent
    }

    var destinationLastComponent: String {
        (destinationPath as NSString).lastPathComponent
    }
}

enum CopyMode: String, Codable, CaseIterable {
    case copy = "copy"
    case sync = "sync"

    var displayName: String {
        switch self {
        case .copy: return "Copy"
        case .sync: return "Mirror"
        }
    }

    var description: String {
        switch self {
        case .copy:
            return "Only copies new and changed files. Nothing is ever deleted from the destination."
        case .sync:
            return "Makes the destination match the source exactly. Files on the destination that don't exist in the source will be DELETED."
        }
    }
}

enum Schedule: Codable {
    case hourly
    case daily(hour: Int, minute: Int)
    case weekly(day: Int, hour: Int, minute: Int) // 0=Sunday
    case custom(cronExpression: String)
}

enum Status: Codable, Equatable {
    case idle
    case running
    case success
    case failed(String)
}

struct LastRunInfo: Codable {
    var timestamp: Date
    var duration: TimeInterval?
    var filesTransferred: Int?
    var bytesTransferred: Int64?
    var error: String?

    var isSuccess: Bool { error == nil }
}
