@testable import AdaSprite
import Foundation
import Math
import Testing

@Suite("Sprite animation")
struct SpriteAnimationTests {
    /// Drives the state machine alone; the system tests cover the world, textures and events.
    private struct Player {
        var animator = SpriteAnimator()
        let clip: SpriteAnimationClip

        init(_ clip: SpriteAnimationClip) {
            self.clip = clip
            animator.currentClip = clip.name
        }

        mutating func advance(_ delta: Double) -> [SpriteAnimationEvent.Kind] {
            animator.advance(by: delta, in: clip)
        }
    }

    @Test("A looping clip wraps and reports the cycle")
    func looping() {
        var player = Player(.row("run", row: 0, columns: 0..<3, framesPerSecond: 10))
        #expect(player.advance(0.05).isEmpty)
        #expect(player.advance(0.06) == [.frameChanged(1)])
        #expect(player.advance(0.2) == [.frameChanged(2), .looped, .frameChanged(0)])
        #expect(player.animator.frameIndex == 0)
    }

    @Test("A one-shot clip holds its last frame and finishes once")
    func oneShot() {
        var player = Player(.row("hit", row: 0, columns: 0..<2, framesPerSecond: 10, playbackMode: .once))
        #expect(player.advance(0.1) == [.frameChanged(1)])
        #expect(player.advance(0.1) == [.finished])
        #expect(player.animator.frameIndex == 1)
        #expect(!player.animator.isPlaying)
        #expect(player.advance(1).isEmpty)
    }

    @Test("Ping-pong reverses at both ends without repeating the end frames")
    func pingPong() {
        var player = Player(.row("idle", row: 0, columns: 0..<3, framesPerSecond: 10, playbackMode: .pingPong))
        var visited: [Int] = []
        for _ in 0..<6 {
            for case .frameChanged(let index) in player.advance(0.1) { visited.append(index) }
        }
        #expect(visited == [1, 2, 1, 0, 1, 2])
    }

    @Test("Per-frame durations and markers are honored")
    func durationsAndMarkers() {
        let clip = SpriteAnimationClip(
            name: "attack",
            frames: [
                SpriteAnimationFrame(atlasCoordinates: [0, 0]),
                SpriteAnimationFrame(atlasCoordinates: [1, 0], duration: 2, marker: "hit"),
                SpriteAnimationFrame(atlasCoordinates: [2, 0])
            ],
            framesPerSecond: 10,
            playbackMode: .once
        )
        var player = Player(clip)
        #expect(player.advance(0.1) == [.frameChanged(1), .marker("hit")])
        #expect(player.advance(0.15).isEmpty)
        #expect(player.advance(0.05) == [.frameChanged(2)])
    }

    @Test("Speed scales time and invalid values stop playback", arguments: [Float(0), -1, .nan, .infinity])
    func speed(value: Float) {
        var player = Player(.row("run", row: 0, columns: 0..<3, framesPerSecond: 10))
        player.animator.speed = value
        #expect(player.advance(1).isEmpty)
        #expect(player.animator.frameIndex == 0)

        player.animator.speed = 2
        #expect(player.advance(0.05) == [.frameChanged(1)])
    }

    @Test("Degenerate clips cannot hang the update")
    func degenerate() {
        var zeroFPS = Player(.row("a", row: 0, columns: 0..<2, framesPerSecond: 0))
        #expect(zeroFPS.advance(1).isEmpty)

        var zero = Player(SpriteAnimationClip(
            name: "b",
            frames: [SpriteAnimationFrame(atlasCoordinates: [0, 0], duration: 0), SpriteAnimationFrame(atlasCoordinates: [1, 0], duration: 0)]
        ))
        #expect(zero.advance(1).isEmpty)

        var empty = Player(SpriteAnimationClip(name: "c", frames: []))
        #expect(empty.advance(1).isEmpty)

        var huge = Player(.row("d", row: 0, columns: 0..<2, framesPerSecond: 1_000_000))
        _ = huge.advance(1_000_000)
        #expect((0..<2).contains(huge.animator.frameIndex))
    }

    @Test("Selecting a clip rewinds it, selecting the same clip keeps the frame, and restartCount replays")
    func controls() {
        let clip = SpriteAnimationClip.row("idle", row: 0, columns: 0..<3)
        var animator = SpriteAnimator(initialClip: "idle")
        _ = animator.advance(by: 0.09, in: clip)
        #expect(animator.frameIndex == 1)

        animator.play("idle")
        #expect(animator.frameIndex == 1)
        animator.play("idle", restart: true)
        #expect(animator.frameIndex == 0)

        _ = animator.advance(by: 0.09, in: clip)
        animator.currentClip = "run"
        #expect(animator.frameIndex == 0)

        animator.currentClip = "idle"
        _ = animator.advance(by: 0.09, in: clip)
        animator.restartCount += 1
        _ = animator.advance(by: 0, in: clip)
        #expect(animator.frameIndex == 0)

        _ = animator.advance(by: 0.09, in: clip)
        animator.pause()
        #expect(animator.advance(by: 1, in: clip).isEmpty)
        animator.stop()
        #expect(animator.frameIndex == 0)
        #expect(!animator.isPlaying)
    }

    @Test("Descriptors reject clips that could never play")
    func validation() throws {
        let frame = SpriteAnimationFrame(atlasCoordinates: [0, 0])
        func descriptor(_ clips: [SpriteAnimationClip], image: String = "a.png") -> SpriteAnimationSetDescriptor {
            SpriteAnimationSetDescriptor(image: image, clips: clips)
        }
        try descriptor([SpriteAnimationClip(name: "ok", frames: [frame])]).validate()
        #expect(throws: SpriteAnimationError.self) { try descriptor([], image: "").validate() }
        #expect(throws: SpriteAnimationError.self) { try descriptor([SpriteAnimationClip(name: "", frames: [frame])]).validate() }
        #expect(throws: SpriteAnimationError.self) {
            try descriptor([SpriteAnimationClip(name: "a", frames: [frame]), SpriteAnimationClip(name: "a", frames: [frame])]).validate()
        }
        #expect(throws: SpriteAnimationError.self) {
            try descriptor([SpriteAnimationClip(name: "a", frames: [frame], framesPerSecond: 0)]).validate()
        }
        // A frame needs exactly one pixel source.
        var both = frame
        both.region = RectInt(x: 0, y: 0, width: 1, height: 1)
        var neither = frame
        neither.atlasCoordinates = nil
        for bad in [both, neither] {
            #expect(throws: SpriteAnimationError.self) { try descriptor([SpriteAnimationClip(name: "a", frames: [bad])]).validate() }
        }
    }

    @Test("Descriptors round trip through Codable and sparse data gets defaults")
    func coding() throws {
        let clip = SpriteAnimationClip(
            name: "attack",
            frames: [
                SpriteAnimationFrame(atlasCoordinates: [3, 1], duration: 1.5, marker: "hit"),
                SpriteAnimationFrame(region: RectInt(x: 4, y: 5, width: 6, height: 7))
            ],
            framesPerSecond: 8,
            playbackMode: .pingPong
        )
        let descriptor = SpriteAnimationSetDescriptor(image: "hero.png", cellSize: SizeInt(width: 16, height: 16), filter: .nearest, clips: [clip])
        let decoded = try JSONDecoder().decode(SpriteAnimationSetDescriptor.self, from: JSONEncoder().encode(descriptor))
        #expect(decoded == descriptor)

        let coordinates = try String(decoding: JSONEncoder().encode(PointInt(x: 2, y: 0)), as: UTF8.self)
        let sparse = try JSONDecoder().decode(SpriteAnimationFrame.self, from: Data(#"{"atlasCoordinates":\#(coordinates)}"#.utf8))
        #expect(sparse.atlasCoordinates == PointInt(x: 2, y: 0))
        #expect(sparse.duration == 1)
        #expect(sparse.marker == nil)

        let minimal = try JSONDecoder().decode(SpriteAnimationSetDescriptor.self, from: Data(#"{"image":"a.png"}"#.utf8))
        #expect(minimal.filter == .linear)
        #expect(minimal.clips.isEmpty)

        let animator = SpriteAnimator(initialClip: "attack", speed: 2, restartCount: 3)
        let copy = try JSONDecoder().decode(SpriteAnimator.self, from: JSONEncoder().encode(animator))
        #expect(copy.currentClip == "attack")
        #expect(copy.speed == 2)
        #expect(copy.restartCount == 3)
        #expect(copy.animations == nil)
    }
}
