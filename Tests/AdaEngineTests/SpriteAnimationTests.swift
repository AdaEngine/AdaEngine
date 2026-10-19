@testable import AdaSprite
import Foundation
import Math
import Testing

@Suite("Sprite animation")
struct SpriteAnimationTests {
    private func animator(_ clip: SpriteAnimationClip) -> SpriteAnimator {
        SpriteAnimator(clips: [clip])
    }

    @Test("A looping clip wraps and reports the cycle")
    func looping() {
        var animator = animator(.row("run", row: 0, columns: 0..<3, framesPerSecond: 10))
        #expect(animator.advance(by: 0.05).isEmpty)
        #expect(animator.advance(by: 0.06) == [.frameChanged(1)])
        #expect(animator.advance(by: 0.2) == [.frameChanged(2), .looped, .frameChanged(0)])
        #expect(animator.frameIndex == 0)
    }

    @Test("A one-shot clip holds its last frame and finishes once")
    func oneShot() {
        var animator = animator(.row("hit", row: 0, columns: 0..<2, framesPerSecond: 10, playbackMode: .once))
        #expect(animator.advance(by: 0.1) == [.frameChanged(1)])
        #expect(animator.advance(by: 0.1) == [.finished])
        #expect(animator.frameIndex == 1)
        #expect(!animator.isPlaying)
        #expect(animator.advance(by: 1).isEmpty)
    }

    @Test("Ping-pong reverses at both ends without repeating the end frames")
    func pingPong() {
        var animator = animator(.row("idle", row: 0, columns: 0..<3, framesPerSecond: 10, playbackMode: .pingPong))
        var visited: [Int] = []
        for _ in 0..<6 {
            for case .frameChanged(let index) in animator.advance(by: 0.1) { visited.append(index) }
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
        var animator = animator(clip)
        #expect(animator.advance(by: 0.1) == [.frameChanged(1), .marker("hit")])
        #expect(animator.advance(by: 0.15).isEmpty)
        #expect(animator.advance(by: 0.05) == [.frameChanged(2)])
    }

    @Test("Speed scales time and invalid values stop playback", arguments: [Float(0), -1, .nan, .infinity])
    func speed(value: Float) {
        var animator = animator(.row("run", row: 0, columns: 0..<3, framesPerSecond: 10))
        animator.speed = value
        #expect(animator.advance(by: 1).isEmpty)
        #expect(animator.frameIndex == 0)

        animator.speed = 2
        #expect(animator.advance(by: 0.05) == [.frameChanged(1)])
    }

    @Test("Degenerate clips cannot hang the update")
    func degenerate() {
        var zeroFPS = animator(.row("a", row: 0, columns: 0..<2, framesPerSecond: 0))
        #expect(zeroFPS.advance(by: 1).isEmpty)

        let zeroLength = SpriteAnimationClip(
            name: "b",
            frames: [SpriteAnimationFrame(atlasCoordinates: [0, 0], duration: 0), SpriteAnimationFrame(atlasCoordinates: [1, 0], duration: 0)]
        )
        var zero = animator(zeroLength)
        #expect(zero.advance(by: 1).isEmpty)

        var empty = animator(SpriteAnimationClip(name: "c", frames: []))
        #expect(empty.advance(by: 1).isEmpty)

        var huge = animator(.row("d", row: 0, columns: 0..<2, framesPerSecond: 1_000_000))
        _ = huge.advance(by: 1_000_000)
        #expect((0..<2).contains(huge.frameIndex))
    }

    @Test("play() switches clips, keeps the frame for the same clip and ignores unknown names")
    func playing() {
        var animator = SpriteAnimator(clips: [.row("idle", row: 0, columns: 0..<3), .row("run", row: 1, columns: 0..<3)])
        _ = animator.advance(by: 0.09)
        #expect(animator.frameIndex == 1)

        animator.play("idle")
        #expect(animator.frameIndex == 1)
        animator.play("idle", restart: true)
        #expect(animator.frameIndex == 0)
        animator.play("run")
        #expect(animator.currentClip == "run")
        animator.play("missing")
        #expect(animator.currentClip == "run")

        animator.pause()
        #expect(animator.advance(by: 1).isEmpty)
        animator.stop()
        #expect(animator.frameIndex == 0)
    }

    @Test("Resources round trip through Codable and old data gets defaults")
    func coding() throws {
        let clip = SpriteAnimationClip(
            name: "attack",
            frames: [SpriteAnimationFrame(atlasCoordinates: [3, 1], duration: 1.5, marker: "hit")],
            framesPerSecond: 8,
            playbackMode: .pingPong
        )
        let decoded = try JSONDecoder().decode(SpriteAnimationClip.self, from: JSONEncoder().encode(clip))
        #expect(decoded == clip)

        let coordinates = try String(decoding: JSONEncoder().encode(PointInt(x: 2, y: 0)), as: UTF8.self)
        let sparse = try JSONDecoder().decode(SpriteAnimationFrame.self, from: Data(#"{"atlasCoordinates":\#(coordinates)}"#.utf8))
        #expect(sparse.atlasCoordinates == PointInt(x: 2, y: 0))
        #expect(sparse.duration == 1)
        #expect(sparse.marker == nil)

        let animator = SpriteAnimator(clips: [clip], speed: 2)
        let copy = try JSONDecoder().decode(SpriteAnimator.self, from: JSONEncoder().encode(animator))
        #expect(copy.clips == [clip])
        #expect(copy.currentClip == "attack")
        #expect(copy.speed == 2)
    }
}
