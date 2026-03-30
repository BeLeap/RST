import AppKit
import Foundation

@MainActor
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

    static func saveFile(title: String, suggestedName: String, allowedFileTypes: [String]? = nil) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = suggestedName
        panel.allowedFileTypes = allowedFileTypes
        return panel.runModal() == .OK ? panel.url : nil
    }
}
