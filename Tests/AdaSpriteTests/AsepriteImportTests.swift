@testable import AdaSprite
import Foundation
import Math
import Testing

@Suite("Aseprite import")
struct AsepriteImportTests {
    /// Output of `aseprite -b hero.aseprite --sheet hero.png --data hero.json --format json-array --list-tags`, trimmed to what matters.
    private static let arrayExport = #"""
    {
      "frames": [
        { "filename": "hero 0.aseprite", "frame": { "x": 0, "y": 0, "w": 16, "h": 16 }, "rotated": false, "trimmed": false,
          "spriteSourceSize": { "x": 0, "y": 0, "w": 16, "h": 16 }, "sourceSize": { "w": 16, "h": 16 }, "duration": 100 },
        { "filename": "hero 1.aseprite", "frame": { "x": 16, "y": 0, "w": 16, "h": 16 }, "rotated": false, "trimmed": false,
          "spriteSourceSize": { "x": 0, "y": 0, "w": 16, "h": 16 }, "sourceSize": { "w": 16, "h": 16 }, "duration": 100 },
        { "filename": "hero 2.aseprite", "frame": { "x": 32, "y": 0, "w": 16, "h": 16 }, "rotated": false, "trimmed": false,
          "spriteSourceSize": { "x": 0, "y": 0, "w": 16, "h": 16 }, "sourceSize": { "w": 16, "h": 16 }, "duration": 300 },
        { "filename": "hero 3.aseprite", "frame": { "x": 48, "y": 0, "w": 16, "h": 16 }, "rotated": false, "trimmed": false,
          "spriteSourceSize": { "x": 0, "y": 0, "w": 16, "h": 16 }, "sourceSize": { "w": 16, "h": 16 }, "duration": 200 }
      ],
      "meta": {
        "app": "https://www.aseprite.org/", "version": "1.3.10", "image": "hero.png", "format": "RGBA8888",
        "size": { "w": 64, "h": 16 }, "scale": "1",
        "frameTags": [
          { "name": "idle", "from": 0, "to": 1, "direction": "forward", "color": "#000000ff" },
          { "name": "walk", "from": 1, "to": 3, "direction": "pingpong", "color": "#000000ff" },
          { "name": "back", "from": 0, "to": 2, "direction": "reverse", "color": "#000000ff" },
          { "name": "swing", "from": 2, "to": 3, "direction": "forward", "repeat": "1", "color": "#000000ff" }
        ]
      }
    }
    """#

    @Test("Frame tags become clips with regions, directions and shared-step timing")
    func tags() throws {
        let sheet = try AsepriteSheet(data: Data(Self.arrayExport.utf8))
        #expect(sheet.image == "hero.png")
        #expect(sheet.size == SizeInt(width: 64, height: 16))
        #expect(sheet.clips.map(\.name) == ["idle", "walk", "back", "swing"])

        let idle = try #require(sheet.clips.first)
        #expect(idle.playbackMode == .loop)
        #expect(idle.framesPerSecond == 10) // 100 ms frames
        #expect(idle.frames.map(\.region) == [RectInt(x: 0, y: 0, width: 16, height: 16), RectInt(x: 16, y: 0, width: 16, height: 16)])
        #expect(idle.frames.allSatisfy { $0.atlasCoordinates == nil && $0.duration == 1 })

        // 100/300/200 ms share a 100 ms step, so the 300 ms frame lasts three units.
        let walk = sheet.clips[1]
        #expect(walk.playbackMode == .pingPong)
        #expect(walk.framesPerSecond == 10)
        #expect(walk.frames.map(\.duration) == [1, 3, 2])

        let back = sheet.clips[2]
        #expect(back.playbackMode == .loop)
        #expect(back.frames.map { $0.region?.origin.x } == [32, 16, 0])

        #expect(sheet.clips[3].playbackMode == .once)
    }

    @Test("A sheet without tags is one default clip of every frame")
    func untagged() throws {
        let json = #"""
        { "frames": [
            { "filename": "a 0", "frame": { "x": 0, "y": 0, "w": 8, "h": 8 }, "duration": 80 },
            { "filename": "a 1", "frame": { "x": 8, "y": 0, "w": 8, "h": 8 }, "duration": 80 } ],
          "meta": { "image": "a.png" } }
        """#
        let sheet = try AsepriteSheet(data: Data(json.utf8))
        #expect(sheet.clips.map(\.name) == ["default"])
        #expect(sheet.clips[0].frames.count == 2)
        #expect(sheet.clips[0].framesPerSecond == 12.5) // 80 ms
    }

    @Test("The hash layout is ordered by the frame number, not by dictionary order")
    func hashLayout() throws {
        let json = #"""
        { "frames": {
            "hero 10.aseprite": { "frame": { "x": 100, "y": 0, "w": 8, "h": 8 }, "duration": 100 },
            "hero 2.aseprite": { "frame": { "x": 20, "y": 0, "w": 8, "h": 8 }, "duration": 100 },
            "hero 0.aseprite": { "frame": { "x": 0, "y": 0, "w": 8, "h": 8 }, "duration": 100 } },
          "meta": { "image": "hero.png" } }
        """#
        let sheet = try AsepriteSheet(data: Data(json.utf8))
        #expect(sheet.clips[0].frames.compactMap { $0.region?.origin.x } == [0, 20, 100])
    }

    @Test("Exports that would draw misplaced or are malformed fail with a clear error")
    func rejections() throws {
        func parse(_ json: String) throws -> AsepriteSheet { try AsepriteSheet(data: Data(json.utf8)) }
        let trimmed = #"{ "frames": [ { "frame": { "x": 0, "y": 0, "w": 4, "h": 4 }, "trimmed": true, "duration": 100 } ] }"#
        #expect(throws: AsepriteImportError.self) { try parse(trimmed) }
        #expect(throws: AsepriteImportError.self) { try parse("not json") }
        #expect(throws: AsepriteImportError.self) { try parse(#"{ "frames": [] }"#) }
        let badTag = #"""
        { "frames": [ { "frame": { "x": 0, "y": 0, "w": 4, "h": 4 }, "duration": 100 } ],
          "meta": { "frameTags": [ { "name": "x", "from": 0, "to": 4 } ] } }
        """#
        #expect(throws: AsepriteImportError.self) { try parse(badTag) }
        let unnumbered = #"""
        { "frames": { "a": { "frame": { "x": 0, "y": 0, "w": 4, "h": 4 }, "duration": 100 },
                      "b": { "frame": { "x": 4, "y": 0, "w": 4, "h": 4 }, "duration": 100 } } }
        """#
        #expect(throws: AsepriteImportError.self) { try parse(unnumbered) }
    }

    @Test("The imported descriptor is nearest-filtered, validated and names the image")
    func descriptor() throws {
        let sheet = try AsepriteSheet(data: Data(Self.arrayExport.utf8))
        let descriptor = try sheet.descriptor()
        #expect(descriptor.image == "hero.png")
        #expect(descriptor.filter == .nearest)
        #expect(descriptor.clips == sheet.clips)
        #expect(try sheet.descriptor(imagePath: "Art/hero.png").image == "Art/hero.png")

        let anonymous = try AsepriteSheet(data: Data(#"{ "frames": [ { "frame": { "x": 0, "y": 0, "w": 4, "h": 4 }, "duration": 100 } ] }"#.utf8))
        #expect(throws: AsepriteImportError.self) { try anonymous.descriptor() }
        #expect(try anonymous.descriptor(imagePath: "a.png").image == "a.png")
    }
}
