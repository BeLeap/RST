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
            // 44.1 kHz AAC improves playback compatibility across third-party players.
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        try transcodeAudio(from: sourceWAVURL, to: destinationM4AURL, outputSettings: settings)
    }

    static func convertToWAV(from sourceURL: URL, to destinationWAVURL: URL) throws {
        guard isImportableAudioExtension(sourceURL.pathExtension) else {
            throw AudioFileTranscoderError.unsupportedInputFormat(sourceURL.lastPathComponent)
        }

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

        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let outputCapacity = AVAudioFrameCount((Double(inputBufferCapacity) * ratio).rounded(.up)) + 1_024

        var reachedEndOfInput = false
        var inputReadError: Error?

        while true {
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
                throw AudioFileTranscoderError.failedToCreateAudioBuffer
            }

            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
                if reachedEndOfInput {
                    outStatus.pointee = .endOfStream
                    return nil
                }

                do {
                    try inputFile.read(into: inputBuffer)
                } catch {
                    inputReadError = error
                    outStatus.pointee = .endOfStream
                    return nil
                }

                if inputBuffer.frameLength == 0 {
                    reachedEndOfInput = true
                    outStatus.pointee = .endOfStream
                    return nil
                }

                outStatus.pointee = .haveData
                return inputBuffer
            }

            if let conversionError {
                throw conversionError
            }

            if let inputReadError {
                throw inputReadError
            }

            if outputBuffer.frameLength > 0 {
                try outputFile.write(from: outputBuffer)
            }

            switch status {
            case .haveData, .inputRanDry:
                continue
            case .endOfStream:
                return
            case .error:
                throw NSError(
                    domain: "AudioFileTranscoder",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Audio conversion failed with converter error status."]
                )
            @unknown default:
                throw NSError(
                    domain: "AudioFileTranscoder",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown conversion status."]
                )
            }
        }
    }
}
