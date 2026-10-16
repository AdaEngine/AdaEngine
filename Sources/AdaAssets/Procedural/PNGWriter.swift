//
//  PNGWriter.swift
//  AdaEngine
//

import Foundation

public enum PNGWritingError: Error, Equatable, Sendable {
    case invalidSize(width: Int, height: Int)
    case pixelCountMismatch
}

/// Encodes 8-bit RGBA images as PNG without compression (stored deflate blocks).
///
/// Procedural sprites are small, so the larger files are acceptable, and the encoder has no
/// dependency on platform image frameworks or zlib, which makes the output identical everywhere.
public struct PNGWriter: Sendable {
    public static let maximumDimension = 4096

    public init() {}

    /// - Parameter rgba: `width * height * 4` bytes, row by row from the top.
    public func encode(width: Int, height: Int, rgba: [UInt8]) throws -> Data {
        guard (1...Self.maximumDimension).contains(width), (1...Self.maximumDimension).contains(height) else {
            throw PNGWritingError.invalidSize(width: width, height: height)
        }
        guard rgba.count == width * height * 4 else { throw PNGWritingError.pixelCountMismatch }

        var raw = [UInt8]()
        raw.reserveCapacity((width * 4 + 1) * height)
        for row in 0..<height {
            raw.append(0)
            raw.append(contentsOf: rgba[(row * width * 4)..<((row + 1) * width * 4)])
        }

        var header = Data()
        header.appendBigEndian(UInt32(width))
        header.appendBigEndian(UInt32(height))
        header.append(contentsOf: [8, 6, 0, 0, 0])

        var png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        png.appendChunk("IHDR", header)
        png.appendChunk("IDAT", Self.zlibStored(raw))
        png.appendChunk("IEND", Data())
        return png
    }

    static func zlibStored(_ bytes: [UInt8]) -> Data {
        var stream = Data([0x78, 0x01])
        var offset = 0
        repeat {
            let length = min(65535, bytes.count - offset)
            let isLast = offset + length >= bytes.count
            stream.append(isLast ? 1 : 0)
            stream.append(contentsOf: [UInt8(length & 0xFF), UInt8(length >> 8), UInt8(~length & 0xFF), UInt8((~length >> 8) & 0xFF)])
            stream.append(contentsOf: bytes[offset..<(offset + length)])
            offset += length
        } while offset < bytes.count
        stream.appendBigEndian(adler32(bytes))
        return stream
    }

    static func adler32(_ bytes: [UInt8]) -> UInt32 {
        var a: UInt32 = 1
        var b: UInt32 = 0
        for byte in bytes {
            a = (a + UInt32(byte)) % 65521
            b = (b + a) % 65521
        }
        return (b << 16) | a
    }

    private static let crcTable: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 { value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1 }
        return value
    }

    static func crc32(_ bytes: some Sequence<UInt8>) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes { crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return ~crc
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt32) {
        append(contentsOf: [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)])
    }

    mutating func appendChunk(_ type: String, _ payload: Data) {
        appendBigEndian(UInt32(payload.count))
        let body = Data(type.utf8) + payload
        append(body)
        appendBigEndian(PNGWriter.crc32(body))
    }
}
