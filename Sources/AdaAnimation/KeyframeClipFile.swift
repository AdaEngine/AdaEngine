//
//  KeyframeClipFile.swift
//  AdaAnimation
//

import AdaUtils
import Foundation
import Math

/// Errors when decoding a keyframe clip JSON file.
public enum KeyframeClipDecodeError: Error, Sendable {
    case unsupportedVersion(Int)
    case unknownTrackType(String)
    case invalidValueCount(expected: Int, got: Int)
}

// MARK: - DTO

private struct KeyframeClipFileDTO: Codable {
    var version: Int
    var name: String
    /// Seconds (JSON number); maps to ``KeyframeClip/duration`` (`TimeInterval` / `Float`).
    var duration: Double
    var repeatMode: KeyframeRepeatMode
    var tracks: [KeyframeTrackDTO]
}

private struct KeyframeTrackDTO: Codable {
    var type: String
    var targetEntityName: String
    var keyframes: [KeyframeRowDTO]
}

private struct KeyframeRowDTO: Codable {
    var time: Double
    var value: [Float]
    var curveToNext: KeyframeCurveKind?
}

public extension KeyframeClip {

    /// Decode version `1` JSON (see ``encodeToJSONData()``).
    init(jsonData: Data) throws {
        let decoder = JSONDecoder()
        let dto = try decoder.decode(KeyframeClipFileDTO.self, from: jsonData)
        guard dto.version == 1 else {
            throw KeyframeClipDecodeError.unsupportedVersion(dto.version)
        }
        var tracks: [KeyframeTrack] = []
        tracks.reserveCapacity(dto.tracks.count)
        for t in dto.tracks {
            try tracks.append(t.makeTrack())
        }
        self.init(
            name: dto.name,
            duration: TimeInterval(dto.duration),
            repeatMode: dto.repeatMode,
            tracks: tracks
        )
    }

    /// Encode as JSON version `1`.
    func encodeToJSONData(prettyPrinted: Bool = false) throws -> Data {
        let dto = KeyframeClipFileDTO(
            version: 1,
            name: name,
            duration: Double(duration),
            repeatMode: repeatMode,
            tracks: tracks.map { KeyframeTrackDTO(track: $0) }
        )
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(dto)
    }
}

private extension KeyframeTrackDTO {
    init(track: KeyframeTrack) {
        switch track {
        case .transformPosition(let k):
            self.type = "transformPosition"
            self.targetEntityName = k.targetEntityName
            self.keyframes = k.keyframes.map { KeyframeRowDTO(vector3: $0) }
        case .transformScale(let k):
            self.type = "transformScale"
            self.targetEntityName = k.targetEntityName
            self.keyframes = k.keyframes.map { KeyframeRowDTO(vector3: $0) }
        case .transformRotation(let k):
            self.type = "transformRotation"
            self.targetEntityName = k.targetEntityName
            self.keyframes = k.keyframes.map { KeyframeRowDTO(quat: $0) }
        case .cameraOrthographicScale(let k):
            self.type = "cameraOrthographicScale"
            self.targetEntityName = k.targetEntityName
            self.keyframes = k.keyframes.map { KeyframeRowDTO(scalar: $0) }
        }
    }

    func makeTrack() throws -> KeyframeTrack {
        switch type {
        case "transformPosition":
            return .transformPosition(Vector3KeyframeTrack(
                targetEntityName: targetEntityName,
                keyframes: try keyframes.map { try $0.toVector3Keyframe() }
            ))
        case "transformScale":
            return .transformScale(Vector3KeyframeTrack(
                targetEntityName: targetEntityName,
                keyframes: try keyframes.map { try $0.toVector3Keyframe() }
            ))
        case "transformRotation":
            return .transformRotation(QuaternionKeyframeTrack(
                targetEntityName: targetEntityName,
                keyframes: try keyframes.map { try $0.toQuaternionKeyframe() }
            ))
        case "cameraOrthographicScale":
            return .cameraOrthographicScale(ScalarKeyframeTrack(
                targetEntityName: targetEntityName,
                keyframes: try keyframes.map { try $0.toScalarKeyframe() }
            ))
        default:
            throw KeyframeClipDecodeError.unknownTrackType(type)
        }
    }
}

private extension KeyframeRowDTO {
    init(vector3 k: Vector3Keyframe) {
        self.time = Double(k.time)
        self.value = [k.value.x, k.value.y, k.value.z]
        self.curveToNext = k.curveToNext
    }

    init(quat k: QuaternionKeyframe) {
        self.time = Double(k.time)
        self.value = [k.value.x, k.value.y, k.value.z, k.value.w]
        self.curveToNext = k.curveToNext
    }

    init(scalar k: ScalarKeyframe) {
        self.time = Double(k.time)
        self.value = [Float(k.value)]
        self.curveToNext = k.curveToNext
    }

    func toVector3Keyframe() throws -> Vector3Keyframe {
        guard value.count == 3 else {
            throw KeyframeClipDecodeError.invalidValueCount(expected: 3, got: value.count)
        }
        return Vector3Keyframe(
            time: TimeInterval(time),
            value: Vector3(value[0], value[1], value[2]),
            curveToNext: curveToNext ?? .linear
        )
    }

    func toQuaternionKeyframe() throws -> QuaternionKeyframe {
        guard value.count == 4 else {
            throw KeyframeClipDecodeError.invalidValueCount(expected: 4, got: value.count)
        }
        var q = Quat.identity
        q.x = value[0]
        q.y = value[1]
        q.z = value[2]
        q.w = value[3]
        return QuaternionKeyframe(
            time: TimeInterval(time),
            value: q,
            curveToNext: curveToNext ?? .linear
        )
    }

    func toScalarKeyframe() throws -> ScalarKeyframe {
        guard value.count == 1 else {
            throw KeyframeClipDecodeError.invalidValueCount(expected: 1, got: value.count)
        }
        return ScalarKeyframe(
            time: TimeInterval(time),
            value: Double(value[0]),
            curveToNext: curveToNext ?? .linear
        )
    }
}
