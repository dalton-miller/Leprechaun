import AppKit

struct FilePicker {
    /// Opens an NSOpenPanel to select a directory.
    /// - Returns: The selected URL, or nil if the user cancelled.
    static func selectDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        // runModal() is blocking, which is generally acceptable for a modal file picker.
        if panel.runModal() == .OK {
            return panel.url
        }

        return nil
    }
}
