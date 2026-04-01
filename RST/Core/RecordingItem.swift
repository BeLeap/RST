import Foundation

struct RecordingItem: Identifiable, Hashable {
    let audioURL: URL
    let transcriptURL: URL?
    let summaryURL: URL?
    let createdAt: Date

    var id: String { audioURL.path }

    var title: String {
        audioURL.deletingPathExtension().lastPathComponent
    }
}
