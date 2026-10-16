//
//  WAV.swift
//  AdaEngine
//

import Foundation

public enum WAVError: Error, Equatable, Sendable {
    case invalidFile
    case unsupportedFormat(String)
    case tooLarge
    case invalidAudio
}

/// Decoded PCM audio with samples interleaved by channel and normalized to `-1...1`.
public struct WAVAudio: Sendable, Equatable {
    public var sampleRate: Int
    public var channels: Int
    public var samples: [Float]

    public init(sampleRate: Int, channels: Int, samples: [Float]) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.samples = samples
    }

    public var frameCount: Int { channels > 0 ? samples.count / channels : 0 }
    public var duration: Double { sampleRate > 0 ? Double(frameCount) / Double(sampleRate) : 0 }

    /// Average of all channels.
    public var mono: [Float] {
        guard channels > 1 else { return samples }
        return (0..<frameCount).map { frame in
            var sum: Float = 0
            for channel in 0..<channels { sum += samples[frame * channels + channel] }
            return sum / Float(channels)
        }
    }
}

/// Encodes 16-bit PCM WAV files.
public struct WAVWriter: Sendable {
    public static let maximumSamples = 48_000 * 60 * 2

    public init() {}

    /// - Parameter samples: Interleaved samples. Values outside `-1...1` are clipped.
    public func encode(_ audio: WAVAudio) throws -> Data {
        guard (1...2).contains(audio.channels), (8000...192_000).contains(audio.sampleRate), !audio.samples.isEmpty,
            audio.samples.count % audio.channels == 0, audio.samples.count <= Self.maximumSamples, audio.samples.allSatisfy(\.isFinite)
        else { throw WAVError.invalidAudio }
        let dataLength = audio.samples.count * 2
        var data = Data(capacity: 44 + dataLength)
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(UInt32(36 + dataLength))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(audio.channels))
        data.appendLittleEndian(UInt32(audio.sampleRate))
        data.appendLittleEndian(UInt32(audio.sampleRate * audio.channels * 2))
        data.appendLittleEndian(UInt16(audio.channels * 2))
        data.appendLittleEndian(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(UInt32(dataLength))
        for sample in audio.samples {
            data.appendLittleEndian(UInt16(bitPattern: Int16((max(-1, min(1, sample)) * 32767).rounded())))
        }
        return data
    }
}

/// Decodes integer (8, 16, 24, 32-bit) and 32-bit float PCM WAV files.
public struct WAVReader: Sendable {
    public static let maximumBytes = 64 * 1024 * 1024

    public init() {}

    public func decode(_ data: Data) throws -> WAVAudio {
        guard data.count <= Self.maximumBytes else { throw WAVError.tooLarge }
        let bytes = [UInt8](data)
        guard bytes.count >= 12, String(decoding: bytes[0..<4], as: UTF8.self) == "RIFF", String(decoding: bytes[8..<12], as: UTF8.self) == "WAVE" else {
            throw WAVError.invalidFile
        }
        var format: (tag: Int, channels: Int, rate: Int, bits: Int)?
        var payload: ArraySlice<UInt8>?
        var offset = 12
        while offset + 8 <= bytes.count {
            let id = String(decoding: bytes[offset..<(offset + 4)], as: UTF8.self)
            let length = Int(bytes.readUInt32(at: offset + 4))
            let start = offset + 8
            let end = min(start + length, bytes.count)
            if id == "fmt ", end - start >= 16 {
                var tag = Int(bytes.readUInt16(at: start))
                if tag == 0xFFFE, end - start >= 26 { tag = Int(bytes.readUInt16(at: start + 24)) }
                format = (tag, Int(bytes.readUInt16(at: start + 2)), Int(bytes.readUInt32(at: start + 4)), Int(bytes.readUInt16(at: start + 14)))
            } else if id == "data" {
                payload = bytes[start..<end]
            }
            offset = start + length + (length & 1)
        }
        guard let format, let payload else { throw WAVError.invalidFile }
        guard (1...8).contains(format.channels), format.rate > 0 else { throw WAVError.invalidFile }
        let base = payload.startIndex
        let width = format.bits / 8
        guard [1, 2, 3, 4].contains(width), (format.tag == 1 && format.bits % 8 == 0) || (format.tag == 3 && format.bits == 32) else {
            throw WAVError.unsupportedFormat("format \(format.tag), \(format.bits) bits")
        }
        let count = payload.count / width
        var samples = [Float](repeating: 0, count: count - count % format.channels)
        for index in samples.indices {
            let at = base + index * width
            switch (format.tag, width) {
            case (3, _): samples[index] = Float(bitPattern: bytes.readUInt32(at: at))
            case (_, 1): samples[index] = (Float(bytes[at]) - 128) / 128
            case (_, 2): samples[index] = Float(Int16(bitPattern: bytes.readUInt16(at: at))) / 32768
            case (_, 3):
                let raw = Int32(bytes[at]) | Int32(bytes[at + 1]) << 8 | Int32(bytes[at + 2]) << 16
                samples[index] = Float(raw & 0x80_0000 != 0 ? raw - 0x100_0000 : raw) / 8_388_608
            default: samples[index] = Float(Int32(bitPattern: bytes.readUInt32(at: at))) / 2_147_483_648
            }
        }
        return WAVAudio(sampleRate: format.rate, channels: format.channels, samples: samples)
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) { append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8)]) }

    mutating func appendLittleEndian(_ value: UInt32) {
        append(contentsOf: [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)])
    }
}

private extension [UInt8] {
    func readUInt16(at offset: Int) -> UInt16 { UInt16(self[offset]) | UInt16(self[offset + 1]) << 8 }

    func readUInt32(at offset: Int) -> UInt32 {
        UInt32(self[offset]) | UInt32(self[offset + 1]) << 8 | UInt32(self[offset + 2]) << 16 | UInt32(self[offset + 3]) << 24
    }
}
