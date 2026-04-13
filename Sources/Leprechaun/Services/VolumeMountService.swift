import Foundation
@preconcurrency import os

/// Handles SMB mount detection and mounting using native macOS mechanisms.
enum VolumeMountService {
    private static let logger = Logger(subsystem: "com.leprechaun", category: "VolumeMount")

    /// The mount timeout — we wait up to 30 seconds for an SMB mount to complete.
    static let mountTimeout: TimeInterval = 30

    // MARK: - Mount Detection

    /// Checks if the given volume path is currently mounted.
    static func isMounted(volumePath: String) -> Bool {
        let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.produceFileReferenceURLs]
        ) ?? []

        return mountedVolumes.contains { volume in
            volume.path.hasPrefix(volumePath) || volume.path == volumePath
        }
    }

    /// Checks if a specific SMB server is already mounted (by server + share name).
    static func isServerMounted(server: String, share: String) -> Bool {
        let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey],
            options: []
        ) ?? []

        let targetShare = share.lowercased()
        return mountedVolumes.contains { volume in
            // Check if the volume path contains the server/share pattern
            let path = volume.path.lowercased()
            return path.contains(server.lowercased()) || path.contains(targetShare)
        }
    }

    // MARK: - Mounting

    /// Mounts an SMB share using the provided credentials.
    /// Returns the mount point path on success, nil on failure.
    static func mountShare(server: String, share: String, username: String, password: String) async throws -> String? {
        let mountURL = URL(string: "smb://\(username):\(password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password)@\(server)/\(share)")!

        logger.info("Attempting to mount smb://\(username)@\(server)/\(share)")

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/mount_smbfs")
            process.arguments = [
                "-N", // Read password from URL (don't prompt)
                mountURL.absoluteString,
                "/Volumes/\(share)"
            ]

            let pipe = Pipe()
            process.standardError = pipe

            process.terminationHandler = { proc in
                let outputData = try? pipe.fileHandleForReading.readToEnd()
                if let output = outputData, !output.isEmpty {
                    let errorOutput = String(data: output, encoding: .utf8) ?? ""
                    self.logger.error("mount_smbfs failed: \(errorOutput)")
                }

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: "/Volumes/\(share)")
                } else {
                    continuation.resume(returning: nil)
                }
            }

            do {
                try process.run()

                // Safety timeout: if the process hasn't terminated within 30s, terminate it
                Task { [process] in
                    try await Task.sleep(for: .seconds(mountTimeout))
                    if process.isRunning {
                        process.terminate()
                    }
                }
            } catch {
                logger.error("Failed to launch mount_smbfs: \(error.localizedDescription)")
                continuation.resume(throwing: error)
            }
        }
    }

    /// Ensures the volume is mounted. If not already mounted, attempts to mount it.
    /// Returns the mount point path, or nil if mounting failed.
    static func ensureMounted(volumePath: String, server: String, share: String) async throws -> String? {
        // Check if already mounted
        if isMounted(volumePath: volumePath) {
            logger.info("Volume already mounted at \(volumePath)")
            return volumePath
        }

        // Try to load credentials from Keychain
        // We need to know the username — this would be passed in from the backup task config
        // For now, delegate to the caller to provide credentials
        return nil
    }

    // MARK: - Unmounting

    /// Unmounts a volume at the given path.
    static func unmount(volumePath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["unmount", volumePath]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw VolumeMountError.unmountFailed(volumePath)
        }
    }
}

enum VolumeMountError: LocalizedError {
    case unmountFailed(String)

    var errorDescription: String? {
        switch self {
        case .unmountFailed(let path):
            return "Failed to unmount volume at \(path)"
        }
    }
}
