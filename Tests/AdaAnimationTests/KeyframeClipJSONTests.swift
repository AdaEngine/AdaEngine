//
//  KeyframeClipJSONTests.swift
//

import AdaAnimation
import AdaUtils
import Foundation
import Math
import Testing

struct KeyframeClipJSONTests {

    @Test
    func roundTripVersion1() throws {
        let clip = KeyframeClip(
            name: "test",
            duration: 1,
            repeatMode: .once,
            tracks: [
                .transformPosition(Vector3KeyframeTrack(
                    targetEntityName: "A",
                    keyframes: [
                        Vector3Keyframe(time: 0, value: .zero, curveToNext: .linear),
                        Vector3Keyframe(time: 1, value: Vector3(1, 2, 3), curveToNext: .linear)
                    ]
                )),
                .cameraOrthographicScale(ScalarKeyframeTrack(
                    targetEntityName: "Cam",
                    keyframes: [
                        ScalarKeyframe(time: 0, value: 1, curveToNext: .cubicInOut),
                        ScalarKeyframe(time: 1, value: 2, curveToNext: .hold)
                    ]
                ))
            ]
        )
        let data = try clip.encodeToJSONData(prettyPrinted: true)
        let decoded = try KeyframeClip(jsonData: data)
        #expect(decoded.name == clip.name)
        #expect(decoded.duration == clip.duration)
        #expect(decoded.tracks.count == 2)
    }

    @Test
    func decodeFixture() throws {
        let json = """
        {
          "version" : 1,
          "name" : "fixture",
          "duration" : 2,
          "repeatMode" : "loop",
          "tracks" : [
            {
              "type" : "transformPosition",
              "targetEntityName" : "Hero",
              "keyframes" : [
                { "time" : 0, "value" : [0, 0, 0], "curveToNext" : "linear" },
                { "time" : 2, "value" : [10, 0, 0], "curveToNext" : "linear" }
              ]
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let clip = try KeyframeClip(jsonData: data)
        #expect(clip.name == "fixture")
        #expect(clip.repeatMode == .loop)
        if case .transformPosition(let t) = clip.tracks[0] {
            #expect(t.targetEntityName == "Hero")
            #expect(t.keyframes.count == 2)
        } else {
            Issue.record("Expected transformPosition track")
        }
    }
}
