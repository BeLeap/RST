import AVFoundation
import Foundation

enum AudioFileTranscoderError: LocalizedError {
    case unsupportedInputFormat(String)
    case failedToCreateAudioBuffer

    var errorDescription: String? {
        switch self {
        case .unsupportedInputFormat(let fileName):
            return "Unsupported audio format: \(fileName). Import WAV, M4A, AAC, MP3, or MP4 audio."
        case .failedToCreateAudioBuffer:
            return "Failed to allocate audio buffer for conversion."
        }
    }
}

struct AudioFileTranscoder {
    static let compressedExportExtension = "m4a"
    static let importableCompressedExtensions: Set<String> = ["m4a", "aac", "mp3", "mp4"]

    static func exportCompressedAudio(from sourceWAVURL: URL, to destinationM4AURL: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ]
        try transcodeAudio(from: sourceWAVURL, to: destinationM4AURL, outputSettings: settings)
    }

    static func convertToWAV(from sourceURL: URL, to destinationWAVURL: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        try transcodeAudio(from: sourceURL, to: destinationWAVURL, outputSettings: settings)
    }

    static func isImportableAudioExtension(_ pathExtension: String) -> Bool {
        let normalized = pathExtension.lowercased()
        return normalized == "wav" || importableCompressedExtensions.contains(normalized)
    }

    private static func transcodeAudio(from sourceURL: URL, to destinationURL: URL, outputSettings: [String: Any]) throws {
        let inputFile = try AVAudioFile(forReading: sourceURL)
        let outputFile = try AVAudioFile(forWriting: destinationURL, settings: outputSettings)
        let inputFormat = inputFile.processingFormat
        let outputFormat = outputFile.processingFormat

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(
                domain: "AudioFileTranscoder",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to initialize audio converter."]
            )
        }

        let inputBufferCapacity: AVAudioFrameCount = 4_096
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: inputBufferCapacity) else {
            throw AudioFileTranscoderError.failedToCreateAudioBuffer
        }

        while true {
            try inputFile.read(into: inputBuffer)
            if inputBuffer.frameLength == 0 {
                break
            }

            let ratio = outputFormat.sampleRate / inputFormat.sampleRate
            let outputCapacity = AVAudioFrameCount((Double(inputBuffer.frameLength) * ratio).rounded(.up)) + 1_024
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
                throw AudioFileTranscoderError.failedToCreateAudioBuffer
            }

            var didConsumeInput = false
            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
                if didConsumeInput {
                    outStatus.pointee = .noDataNow
                    return nil
                }

                didConsumeInput = true
                outStatus.pointee = .haveData
                return inputBuffer
            }

            if let conversionError {
                throw conversionError
            }

            switch status {
            case .haveData, .inputRanDry:
                if outputBuffer.frameLength > 0 {
                    try outputFile.write(from: outputBuffer)
                }
            case .endOfStream, .noDataNow:
                break
            @unknown default:
                throw NSError(
                    domain: "AudioFileTranscoder",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown conversion status."]
                )
            }

            inputBuffer.frameLength = 0
        }
    }
}
