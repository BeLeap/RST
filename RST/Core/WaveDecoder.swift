import Foundation

func decodeWaveFile(_ url: URL) throws -> [Float] {
    let data = try Data(contentsOf: url)
    guard data.count >= 44 else {
        throw CocoaError(.fileReadCorruptFile)
    }

    return stride(from: 44, to: data.count, by: 2).map { index in
        data[index..<(index + 2)].withUnsafeBytes { bytes in
            let sample = Int16(littleEndian: bytes.load(as: Int16.self))
            return max(-1.0, min(Float(sample) / 32767.0, 1.0))
        }
    }
}
