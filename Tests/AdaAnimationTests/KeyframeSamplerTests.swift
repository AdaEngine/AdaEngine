//
//  KeyframeSamplerTests.swift
//

import AdaAnimation
import AdaUtils
import Math
import Testing

struct KeyframeSamplerTests {

    @Test
    func sampleVector3_linearMidpoint() {
        let keys = [
            Vector3Keyframe(time: 0, value: Vector3(0, 0, 0), curveToNext: .linear),
            Vector3Keyframe(time: 1, value: Vector3(10, 0, 0), curveToNext: .linear)
        ]
        let v = sampleVector3Keyframes(keys, localTime: 0.5)
        #expect(v != nil)
        #expect(abs(Double(v!.x) - 5) < 0.001)
    }

    @Test
    func normalizedTime_loopWraps() {
        let t = keyframeNormalizedLocalTime(playhead: 2.5, duration: 1, mode: .loop)
        #expect(abs(Double(t) - 0.5) < 0.001)
    }

    @Test
    func normalizedTime_pingPong() {
        let t = keyframeNormalizedLocalTime(playhead: 1.5, duration: 1, mode: .pingPong)
        #expect(abs(Double(t) - 0.5) < 0.001)
    }
}
