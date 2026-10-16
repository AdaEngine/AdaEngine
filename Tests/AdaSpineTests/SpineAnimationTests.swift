import AdaSpineRuntime
import Foundation
import Testing

@Suite
struct SpineAnimationTests {
    @Test func loadsRegionAndEvaluatesBoneHierarchy() throws {
        let player = try makePlayer()
        #expect(player.animationNames.sorted() == ["bend", "move", "smooth"])
        #expect(player.pageNames == ["character.png"])
        let rest = try #require(player.snapshot().first)
        #expect(rest.indices.count == 6)
        #expect(rest.vertices.count == 4)
        #expect(abs(centerX(rest) - 10) < 0.001)
        let bones = player.boneSnapshot()
        #expect(bones.map(\.name) == ["root", "body"])
        #expect(bones[0].parentIndex == nil)
        #expect(bones[1].parentIndex == 0)
        #expect(bones[1].x == 10)
        try player.play("move", repeats: false, transitionDuration: 0)
        player.advance(by: 0.5)
        #expect(abs(centerX(try #require(player.snapshot().first)) - 20) < 0.001)
        #expect(player.boneSnapshot()[1].x == 20)
        player.advance(by: 2)
        #expect(player.isComplete)
        #expect(abs(centerX(try #require(player.snapshot().first)) - 30) < 0.001)
    }

    @Test func splineCurveChangesBoneMotion() throws {
        let player = try makePlayer()
        try player.play("smooth", repeats: false, transitionDuration: 0)
        player.advance(by: 0.5)
        // The curve has control values at zero and reaches 20 only at its endpoint.
        let middle = centerX(try #require(player.snapshot().first))
        #expect(middle > 10 && middle < 18)
        player.advance(by: 0.5)
        #expect(abs(centerX(try #require(player.snapshot().first)) - 30) < 0.001)
    }

    @Test func loopingResetAndInstancesAreIndependent() throws {
        let first = try makePlayer()
        let second = try makePlayer()
        try first.play("move", transitionDuration: 0)
        first.advance(by: 1.25)
        #expect(abs(centerX(try #require(first.snapshot().first)) - 15) < 0.001)
        #expect(abs(centerX(try #require(second.snapshot().first)) - 10) < 0.001)
        first.resetToSetupPose()
        #expect(first.time == 0)
        #expect(abs(centerX(try #require(first.snapshot().first)) - 10) < 0.001)
    }

    @Test func transitionsBlendFromCurrentPose() throws {
        let player = try makePlayer()
        try player.play("move", repeats: false, transitionDuration: 0)
        player.advance(by: 1)
        try player.play("bend", transitionDuration: 1)
        player.advance(by: 0.5)
        #expect(abs(centerX(try #require(player.snapshot().first)) - 20) < 0.001)
    }

    @Test func invalidNamesAndTimesPreservePlayback() throws {
        let player = try makePlayer()
        try player.play("move", transitionDuration: 0)
        player.advance(by: 0.25)
        #expect(throws: SpineError.unknownAnimation("missing")) { try player.play("missing") }
        #expect(throws: SpineError.unknownSkin("missing")) { try player.setSkin("missing") }
        #expect(throws: SpineError.invalidTime) { try player.play("move", transitionDuration: .nan) }
        player.advance(by: .nan)
        player.advance(by: -.infinity)
        player.advance(by: -1)
        #expect(player.time == 0.25)
    }

    @Test func invalidExportsReportErrors() {
        #expect(throws: (any Error).self) { try SpineAnimationPlayer(skeleton: Data("{}".utf8), atlas: atlas) }
        #expect(throws: (any Error).self) { try SpineAnimationPlayer(skeleton: Data(json.utf8), atlas: "") }
        #expect(throws: (any Error).self) { try SpineAnimationPlayer(skeleton: Data(json.utf8), atlas: atlas, scale: 0) }
        #expect(throws: (any Error).self) {
            try SpineAnimationPlayer(skeleton: Data(json.replacingOccurrences(of: "4.2.00", with: "4.1.00").utf8), atlas: atlas)
        }
    }

    @Test func weightedMeshFollowsItsInfluencingBone() throws {
        let player = try modifiedPlayer { object in
            object["skins"] = [["name": "default", "attachments": ["body": ["body": [
                "type": "mesh", "uvs": [0, 0, 1, 0, 0, 1], "triangles": [0, 1, 2],
                "vertices": [1, 1, 0, 0, 1, 1, 1, 16, 0, 1, 1, 1, 0, 16, 1]
            ]]]]]
        }
        let rest = try #require(player.snapshot().first)
        #expect(rest.indices == [0, 1, 2])
        #expect(abs(rest.vertices[0].x - 10) < 0.001)
        try player.play("move", repeats: false, transitionDuration: 0)
        player.advance(by: 0.5)
        let moved = try #require(player.snapshot().first)
        #expect(abs(moved.vertices[0].x - 20) < 0.001)
        #expect(abs(moved.vertices[1].x - 36) < 0.001)
    }

    @Test func clippingProducesGeometryInsideTheClipPolygon() throws {
        let player = try modifiedPlayer { object in
            object["slots"] = [
                ["name": "clip", "bone": "root", "attachment": "clip"],
                ["name": "body", "bone": "body", "attachment": "body"],
            ]
            object["skins"] = [["name": "default", "attachments": [
                "clip": ["clip": ["type": "clipping", "end": "body", "vertexCount": 4,
                                  "vertices": [0, -8, 14, -8, 14, 8, 0, 8]]],
                "body": ["body": ["width": 16, "height": 16]],
            ]]]
        }
        let draw = try #require(player.snapshot().first)
        #expect(!draw.indices.isEmpty)
        #expect(draw.vertices.allSatisfy { $0.x >= -0.001 && $0.x <= 14.001 })
        #expect(draw.indices.allSatisfy { $0 < UInt32(draw.vertices.count) })
        #expect(draw.vertices.allSatisfy { $0.u.isFinite && $0.v.isFinite })
    }

    @Test func skinChangeReplacesAttachmentAndKeepsPlayback() throws {
        let player = try modifiedPlayer { object in
            object["skins"] = [
                ["name": "default", "attachments": ["body": ["body": ["width": 16, "height": 16]]]],
                ["name": "large", "attachments": ["body": ["body": ["width": 32, "height": 16]]]],
            ]
        }
        try player.play("move", transitionDuration: 0)
        player.advance(by: 0.5)
        try player.setSkin("large")
        let draw = try #require(player.snapshot().first)
        let width = try #require(draw.vertices.map(\.x).max()) - #require(draw.vertices.map(\.x).min())
        #expect(abs(width - 32) < 0.001)
        #expect(player.time == 0.5)
    }

    @Test func animatedDrawOrderIsPreservedInSnapshots() throws {
        let player = try modifiedPlayer { object in
            object["slots"] = [
                ["name": "front", "bone": "root", "attachment": "body", "color": "ff0000ff"],
                ["name": "back", "bone": "root", "attachment": "body", "color": "00ff00ff"],
            ]
            let attachment = ["body": ["width": 16, "height": 16]]
            object["skins"] = [["name": "default", "attachments": ["front": attachment, "back": attachment]]]
            object["animations"] = ["swap": ["drawOrder": [
                ["time": 0.5, "offsets": [["slot": "front", "offset": 1]]],
            ]]]
        }
        #expect(player.snapshot().first?.vertices.first?.red == 1)
        try player.play("swap", repeats: false, transitionDuration: 0)
        player.advance(by: 0.5)
        #expect(player.snapshot().first?.vertices.first?.green == 1)
        #expect(player.snapshot().last?.vertices.first?.red == 1)
    }

    @Test(arguments: [false, true]) func snapshotsCarryAtlasAlphaModeAndSlotBlend(pma: Bool) throws {
        var object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        object["slots"] = [["name": "body", "bone": "body", "attachment": "body", "blend": "additive", "color": "ffffff80", "dark": "804020"]]
        let player = try SpineAnimationPlayer(skeleton: JSONSerialization.data(withJSONObject: object),
                                              atlas: atlas.replacingOccurrences(of: "size: 64,64", with: "size: 64,64\npma: \(pma)"))
        let draw = try #require(player.snapshot().first)
        #expect(draw.premultipliedAlpha == pma)
        #expect(draw.blendMode == .additive)
        #expect(abs(draw.vertices[0].red - (pma ? draw.vertices[0].alpha : 1)) < 0.001)
        #expect(abs(draw.vertices[0].alpha - 128.0 / 255) < 0.001)
        #expect(abs(draw.vertices[0].darkRed - 128.0 / 255 * (pma ? draw.vertices[0].alpha : 1)) < 0.001)
        #expect(draw.vertices[0].darkAlpha == (pma ? 1 : 0))
    }

    @Test func concurrentImportsAndPlaybackAreSerializedSafely() async throws {
        let player = try makePlayer()
        try player.play("move", transitionDuration: 0)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    let independent = try SpineAnimationPlayer(skeleton: Data(json.utf8), atlas: atlas)
                    for _ in 0..<10 {
                        player.advance(by: 0.01)
                        _ = player.snapshot()
                        _ = independent.snapshot()
                    }
                }
            }
            try await group.waitForAll()
        }
        #expect(abs(player.time - 0.8) < 0.001)
    }

    @Test func officialBinaryAndJSONExportsProduceTheSameGeometry() throws {
        let directory = try #require(Bundle.module.resourceURL).appendingPathComponent("Fixtures")
        let atlas = try String(contentsOf: directory.appendingPathComponent("coin.atlas"), encoding: .utf8)
        let jsonPlayer = try SpineAnimationPlayer(skeleton: Data(contentsOf: directory.appendingPathComponent("coin-pro.json")), atlas: atlas)
        let binaryPlayer = try SpineAnimationPlayer(skeleton: Data(contentsOf: directory.appendingPathComponent("coin-pro.skel")), atlas: atlas, format: .binary)
        #expect(jsonPlayer.animationNames == binaryPlayer.animationNames)
        let animation = try #require(jsonPlayer.animationNames.first)
        try jsonPlayer.play(animation, transitionDuration: 0)
        try binaryPlayer.play(animation, transitionDuration: 0)
        for delta: Float in [0, 0.25, 0.5] {
            jsonPlayer.advance(by: delta)
            binaryPlayer.advance(by: delta)
            let jsonDraws = jsonPlayer.snapshot()
            let binaryDraws = binaryPlayer.snapshot()
            #expect(!jsonDraws.isEmpty)
            #expect(jsonDraws.count == binaryDraws.count)
            for (jsonDraw, binaryDraw) in zip(jsonDraws, binaryDraws) {
                #expect(jsonDraw.indices == binaryDraw.indices)
                #expect(jsonDraw.vertices.count == binaryDraw.vertices.count)
                for (left, right) in zip(jsonDraw.vertices, binaryDraw.vertices) {
                    // JSON rounds keyframe times; binary retains full precision. Require subpixel agreement.
                    #expect(abs(left.x - right.x) < 0.5)
                    #expect(abs(left.y - right.y) < 0.5)
                    #expect(abs(left.u - right.u) < 0.5 / 1_024)
                    #expect(abs(left.v - right.v) < 0.5 / 1_024)
                }
            }
        }
    }

    private func makePlayer() throws -> SpineAnimationPlayer { try .init(skeleton: Data(json.utf8), atlas: atlas) }
    private func centerX(_ draw: SpineDraw) -> Float { draw.vertices.reduce(0) { $0 + $1.x } / Float(draw.vertices.count) }
    private func modifiedPlayer(_ edit: (inout [String: Any]) -> Void) throws -> SpineAnimationPlayer {
        var object = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        edit(&object)
        return try SpineAnimationPlayer(skeleton: JSONSerialization.data(withJSONObject: object), atlas: atlas)
    }
}

private let atlas = """
character.png
size: 64,64
filter: Linear,Linear
body
bounds: 0,0,16,16
"""

private let json = #"""
{
  "skeleton": {"spine": "4.2.00"},
  "bones": [{"name":"root"}, {"name":"body", "parent":"root", "x":10}],
  "slots": [{"name":"body", "bone":"body", "attachment":"body"}],
  "skins": [{"name":"default", "attachments":{"body":{"body":{"width":16,"height":16}}}}],
  "animations": {
    "move":{"bones":{"root":{"translatex":[{"value":0},{"time":1,"value":20}]}}},
    "smooth":{"bones":{"root":{"translatex":[{"value":0,"curve":[0.3,0,0.7,0]},{"time":1,"value":20}]}}},
    "bend":{"bones":{"root":{"translatex":[{"value":0},{"time":1,"value":0}]}}}
  }
}
"""#
