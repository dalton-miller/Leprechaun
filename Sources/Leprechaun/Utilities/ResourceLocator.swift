import Foundation

/// Locates bundled resources (rclone binary) at runtime.
enum ResourceLocator {
    /// Returns the path to the appropriate rclone binary for the current architecture.
    static var rclonePath: String? {
        #if arch(arm64)
        let binaryName = "rclone-darwin-arm64"
        #elseif arch(x86_64)
        let binaryName = "rclone-darwin-x86_64"
        #else
        fatalError("Unsupported architecture")
        #endif

        // When running via SPM: look in the module's bundle resources
        if let bundlePath = Bundle.module.path(forResource: binaryName, ofType: nil) {
            return bundlePath
        }

        // Fallback: look in the main bundle (for when running from Xcode)
        if let mainPath = Bundle.main.path(forResource: binaryName, ofType: nil) {
            return mainPath
        }

        // Last resort: check adjacent to the executable
        if let exePath = Bundle.main.executablePath {
            let exeDir = (exePath as NSString).deletingLastPathComponent
            let fallback = exeDir + "/" + binaryName
            if FileManager.default.fileExists(atPath: fallback) {
                return fallback
            }
        }

        return nil
    }
}
