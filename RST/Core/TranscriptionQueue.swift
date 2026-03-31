import Foundation

enum TranscriptionJobStatus: String, Codable {
    case queued
    case running
    case completed
    case failed
}

struct TranscriptionJob: Codable, Identifiable, Equatable {
    let id: UUID
    let audioPath: String
    let modelPath: String
    let language: String
    var status: TranscriptionJobStatus
    var errorMessage: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        audioPath: String,
        modelPath: String,
        language: String,
        status: TranscriptionJobStatus = .queued,
        errorMessage: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.audioPath = audioPath
        self.modelPath = modelPath
        self.language = language
        self.status = status
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
