//
//  KeyframeClip.swift
//  AdaAnimation
//

import AdaUtils
import Math

/// How playback behaves after the clip passes ``KeyframeClip/duration``.
public enum KeyframeRepeatMode: String, Codable, Sendable, Hashable {
    case once
    case loop
    case pingPong
}

/// Easing between two consecutive keyframes (segment from this keyframe toward the next).
public enum KeyframeCurveKind: String, Codable, Sendable, Hashable {
    case linear
    case hold
    case cubicInOut
}

// MARK: - Keyframe rows

public struct Vector3Keyframe: Sendable, Hashable {
    public var time: TimeInterval
    public var value: Vector3
    public var curveToNext: KeyframeCurveKind

    public init(time: TimeInterval, value: Vector3, curveToNext: KeyframeCurveKind = .linear) {
        self.time = time
        self.value = value
        self.curveToNext = curveToNext
    }
}

public struct QuaternionKeyframe: Sendable, Hashable {
    public var time: TimeInterval
    public var value: Quat
    public var curveToNext: KeyframeCurveKind

    public init(time: TimeInterval, value: Quat, curveToNext: KeyframeCurveKind = .linear) {
        self.time = time
        self.value = value
        self.curveToNext = curveToNext
    }
}

public struct ScalarKeyframe: Sendable, Hashable {
    public var time: TimeInterval
    public var value: Double
    public var curveToNext: KeyframeCurveKind

    public init(time: TimeInterval, value: Double, curveToNext: KeyframeCurveKind = .linear) {
        self.time = time
        self.value = value
        self.curveToNext = curveToNext
    }
}

// MARK: - Tracks

public struct Vector3KeyframeTrack: Sendable, Hashable {
    public var targetEntityName: String
    public var keyframes: [Vector3Keyframe]

    public init(targetEntityName: String, keyframes: [Vector3Keyframe]) {
        self.targetEntityName = targetEntityName
        self.keyframes = keyframes
    }
}

public struct QuaternionKeyframeTrack: Sendable, Hashable {
    public var targetEntityName: String
    public var keyframes: [QuaternionKeyframe]

    public init(targetEntityName: String, keyframes: [QuaternionKeyframe]) {
        self.targetEntityName = targetEntityName
        self.keyframes = keyframes
    }
}

public struct ScalarKeyframeTrack: Sendable, Hashable {
    public var targetEntityName: String
    public var keyframes: [ScalarKeyframe]

    public init(targetEntityName: String, keyframes: [ScalarKeyframe]) {
        self.targetEntityName = targetEntityName
        self.keyframes = keyframes
    }
}

/// One animated property on a named entity.
public enum KeyframeTrack: Sendable, Hashable {
    case transformPosition(Vector3KeyframeTrack)
    case transformScale(Vector3KeyframeTrack)
    case transformRotation(QuaternionKeyframeTrack)
    case cameraOrthographicScale(ScalarKeyframeTrack)
}

/// A keyframe clip driving multiple entity properties with one timeline.
public struct KeyframeClip: Sendable, Hashable {
    public var name: String
    public var duration: TimeInterval
    public var repeatMode: KeyframeRepeatMode
    public var tracks: [KeyframeTrack]

    public init(
        name: String = "",
        duration: TimeInterval,
        repeatMode: KeyframeRepeatMode = .once,
        tracks: [KeyframeTrack] = []
    ) {
        self.name = name
        self.duration = max(0, duration)
        self.repeatMode = repeatMode
        self.tracks = tracks
    }
}
