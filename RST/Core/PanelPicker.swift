import AppKit
import Foundation

enum PanelPicker {
    static func chooseFile(title: String, allowedFileTypes: [String]? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = allowedFileTypes
        return panel.runModal() == .OK ? panel.url : nil
    }
}
