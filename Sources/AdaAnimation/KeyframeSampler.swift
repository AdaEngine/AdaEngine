//
//  KeyframeSampler.swift
//  AdaAnimation
//

import AdaUtils
import Math

/// Maps a playhead to a time in `[0, duration]` according to repeat mode.
public func keyframeNormalizedLocalTime(
    playhead: TimeInterval,
    duration: TimeInterval,
    mode: KeyframeRepeatMode
) -> TimeInterval {
    guard duration > 0 else { return 0 }
    switch mode {
    case .once:
        return min(max(playhead, 0), duration)
    case .loop:
        let t = playhead.truncatingRemainder(dividingBy: duration)
        return t < 0 ? t + duration : t
    case .pingPong:
        let span = duration * 2
        guard span > 0 else { return 0 }
        var t = playhead.truncatingRemainder(dividingBy: span)
        if t < 0 { t += span }
        if t > duration {
            return span - t
        }
        return t
    }
}

/// Linear interpolation on ``Vector3`` keyframes.
public func sampleVector3Keyframes(_ keyframes: [Vector3Keyframe], localTime: TimeInterval) -> Vector3? {
    let sorted = keyframes.sorted { $0.time < $1.time }
    guard !sorted.isEmpty else { return nil }
    if sorted.count == 1 {
        return sorted[0].value
    }
    if localTime <= sorted[0].time {
        return sorted[0].value
    }
    if localTime >= sorted[sorted.count - 1].time {
        return sorted[sorted.count - 1].value
    }
    guard let rightIdx = sorted.firstIndex(where: { $0.time > localTime }), rightIdx > 0 else {
        return sorted.last?.value
    }
    let left = sorted[rightIdx - 1]
    let right = sorted[rightIdx]
    let span = right.time - left.time
    guard span > 0 else { return left.value }
    var u = Double((localTime - left.time) / span)
    u = clamp01(u)
    u = applyCurve(left.curveToNext, u: u)
    return left.value.interpolated(towards: right.value, amount: u)
}

extension Vector3 {
    fileprivate func interpolated(towards other: Vector3, amount: Double) -> Vector3 {
        let a = Float(amount)
        return Vector3(
            x: x + (other.x - x) * a,
            y: y + (other.y - y) * a,
            z: z + (other.z - z) * a
        )
    }
}

/// Spherical interpolation between quaternion keyframes.
public func sampleQuaternionKeyframes(_ keyframes: [QuaternionKeyframe], localTime: TimeInterval) -> Quat? {
    guard !keyframes.isEmpty else { return nil }
    let sorted = keyframes.sorted { $0.time < $1.time }
    if sorted.count == 1 {
        return sorted[0].value
    }
    if localTime <= sorted[0].time {
        return sorted[0].value
    }
    if localTime >= sorted[sorted.count - 1].time {
        return sorted[sorted.count - 1].value
    }
    guard let rightIdx = sorted.firstIndex(where: { $0.time > localTime }), rightIdx > 0 else {
        return sorted.last?.value
    }
    let left = sorted[rightIdx - 1]
    let right = sorted[rightIdx]
    let span = right.time - left.time
    guard span > 0 else { return left.value }
    var u = Double((localTime - left.time) / span)
    u = clamp01(u)
    u = applyCurve(left.curveToNext, u: u)
    return slerp(left.value, right.value, t: Float(u))
}

/// Scalar keyframes (double values).
public func sampleScalarKeyframes(_ keyframes: [ScalarKeyframe], localTime: TimeInterval) -> Double? {
    guard !keyframes.isEmpty else { return nil }
    let sorted = keyframes.sorted { $0.time < $1.time }
    if sorted.count == 1 {
        return sorted[0].value
    }
    if localTime <= sorted[0].time {
        return sorted[0].value
    }
    if localTime >= sorted[sorted.count - 1].time {
        return sorted[sorted.count - 1].value
    }
    guard let rightIdx = sorted.firstIndex(where: { $0.time > localTime }), rightIdx > 0 else {
        return sorted.last?.value
    }
    let left = sorted[rightIdx - 1]
    let right = sorted[rightIdx]
    let span = right.time - left.time
    guard span > 0 else { return left.value }
    var u = Double((localTime - left.time) / span)
    u = clamp01(u)
    u = applyCurve(left.curveToNext, u: u)
    return left.value + (right.value - left.value) * u
}

private func clamp01(_ x: Double) -> Double {
    min(1, max(0, x))
}

private func applyCurve(_ curve: KeyframeCurveKind, u: Double) -> Double {
    switch curve {
    case .linear:
        return u
    case .hold:
        return 0
    case .cubicInOut:
        let t = clamp01(u)
        return t * t * (3 - 2 * t)
    }
}

private func slerp(_ a: Quat, _ b: Quat, t: Float) -> Quat {
    var cosHalfTheta = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
    var b2 = b
    if cosHalfTheta < 0 {
        b2.x = -b.x
        b2.y = -b.y
        b2.z = -b.z
        b2.w = -b.w
        cosHalfTheta = -cosHalfTheta
    }
    if cosHalfTheta >= 1 - Float.ulpOfOne {
        var q = Quat()
        q.x = a.x + (b2.x - a.x) * t
        q.y = a.y + (b2.y - a.y) * t
        q.z = a.z + (b2.z - a.z) * t
        q.w = a.w + (b2.w - a.w) * t
        return q.normalized
    }
    let halfTheta = acos(min(1, max(-1, cosHalfTheta)))
    let sinHalfTheta = sqrt(1 - cosHalfTheta * cosHalfTheta)
    let ra = sin((1 - t) * halfTheta) / sinHalfTheta
    let rb = sin(t * halfTheta) / sinHalfTheta
    var out = Quat()
    out.x = a.x * ra + b2.x * rb
    out.y = a.y * ra + b2.y * rb
    out.z = a.z * ra + b2.z * rb
    out.w = a.w * ra + b2.w * rb
    return out.normalized
}
