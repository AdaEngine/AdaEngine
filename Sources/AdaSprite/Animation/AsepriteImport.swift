import Foundation
import Math

public enum AsepriteImportError: Error, Equatable, LocalizedError {
    case malformed(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .malformed(let message): "Not an Aseprite sprite sheet: \(message)"
        case .unsupported(let message): "Unsupported Aseprite export: \(message)"
        }
    }
}

/// Clips read from the JSON that `aseprite --sheet … --data …` or File > Export Sprite Sheet writes.
///
/// Both the array and hash layouts are accepted. Frame tags become clips; a sheet without tags becomes one `default` clip.
/// Export with Trim and Rotation off: trimmed frames lose their offset, so they are rejected rather than shown misplaced.
public struct AsepriteSheet: Sendable, Equatable {
    /// The `meta.image` path as written by Aseprite, usually next to the JSON.
    public var image: String?
    public var size: SizeInt?
    public var clips: [SpriteAnimationClip]

    public init(data: Data) throws {
        let document: Document
        do {
            document = try JSONDecoder().decode(Document.self, from: data)
        } catch {
            throw AsepriteImportError.malformed("\(error)")
        }
        let frames = try document.frames.sortedFrames()
        guard !frames.isEmpty else { throw AsepriteImportError.malformed("the sheet has no frames") }
        for frame in frames where frame.trimmed == true || frame.rotated == true {
            throw AsepriteImportError.unsupported("trimmed or rotated frames; export without Trim and Rotation")
        }

        self.image = document.meta?.image
        self.size = document.meta?.size.map { SizeInt(width: $0.w, height: $0.h) }
        let tags = document.meta?.frameTags ?? []
        if tags.isEmpty {
            self.clips = [Self.makeClip(name: "default", frames: frames, direction: .forward, playsOnce: false)]
            return
        }
        var clips: [SpriteAnimationClip] = []
        for tag in tags {
            guard tag.from >= 0, tag.to >= tag.from, tag.to < frames.count else {
                throw AsepriteImportError.malformed("tag '\(tag.name)' covers frames \(tag.from)...\(tag.to) of \(frames.count)")
            }
            guard !clips.contains(where: { $0.name == tag.name }) else {
                throw AsepriteImportError.malformed("tag '\(tag.name)' appears twice")
            }
            guard let direction = Direction(rawValue: tag.direction ?? "forward") else {
                throw AsepriteImportError.unsupported("tag direction '\(tag.direction ?? "")'")
            }
            clips.append(Self.makeClip(
                name: tag.name,
                frames: Array(frames[tag.from...tag.to]),
                direction: direction,
                playsOnce: tag.repeat.flatMap { Int($0) } == 1
            ))
        }
        self.clips = clips
    }

    /// A resource for the sheet. `imagePath` is stored in the descriptor, so pass the path relative to the `.spriteanim` file.
    public func descriptor(imagePath: String? = nil) throws -> SpriteAnimationSetDescriptor {
        guard let path = imagePath ?? image else {
            throw AsepriteImportError.malformed("the sheet does not name its image")
        }
        // Aseprite output is pixel art; filtering would blur frame edges.
        let descriptor = SpriteAnimationSetDescriptor(image: path, filter: .nearest, clips: clips)
        try descriptor.validate()
        return descriptor
    }

    // MARK: - Mapping

    private enum Direction: String {
        case forward, reverse, pingpong
        case pingpongReverse = "pingpong_reverse"
    }

    private static func makeClip(name: String, frames: [Frame], direction: Direction, playsOnce: Bool) -> SpriteAnimationClip {
        let ordered = (direction == .reverse || direction == .pingpongReverse) ? Array(frames.reversed()) : frames
        // The longest shared step keeps durations small integers: 100 ms frames become 10 fps, one unit each.
        let step = ordered.map { max($0.duration, 1) }.reduce(0) { gcd($0, $1) }
        let mode: SpriteAnimationPlaybackMode
        switch direction {
        case .forward, .reverse: mode = playsOnce ? .once : .loop
        case .pingpong, .pingpongReverse: mode = .pingPong
        }
        return SpriteAnimationClip(
            name: name,
            frames: ordered.map {
                SpriteAnimationFrame(
                    region: RectInt(x: $0.frame.x, y: $0.frame.y, width: $0.frame.w, height: $0.frame.h),
                    duration: Float(max($0.duration, 1) / max(step, 1))
                )
            },
            framesPerSecond: Float(1000) / Float(max(step, 1)),
            playbackMode: mode
        )
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var (a, b) = (a, b)
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }

    // MARK: - JSON

    private struct Rect: Decodable {
        var x: Int
        var y: Int
        var w: Int
        var h: Int
    }

    private struct Frame: Decodable {
        var filename: String?
        var frame: Rect
        var rotated: Bool?
        var trimmed: Bool?
        var duration: Int
    }

    private struct Tag: Decodable {
        var name: String
        var from: Int
        var to: Int
        var direction: String?
        var `repeat`: String?
    }

    private struct Meta: Decodable {
        var image: String?
        var size: Size?
        var frameTags: [Tag]?

        struct Size: Decodable {
            var w: Int
            var h: Int
        }
    }

    /// The array layout keeps Aseprite's frame order; the hash layout loses it, so frames are ordered by the number in their name.
    private enum Frames: Decodable {
        case array([Frame])
        case hash([String: Frame])

        init(from decoder: any Decoder) throws {
            if let array = try? [Frame](from: decoder) {
                self = .array(array)
            } else {
                self = .hash(try [String: Frame](from: decoder))
            }
        }

        func sortedFrames() throws -> [Frame] {
            switch self {
            case .array(let frames):
                return frames
            case .hash(let frames):
                let keyed = frames.map { (key: $0.key, index: Self.trailingNumber(in: $0.key), frame: $0.value) }
                guard keyed.allSatisfy({ $0.index != nil }) || keyed.count <= 1 else {
                    throw AsepriteImportError.unsupported("hash-layout frames without numbered names; export with the array layout")
                }
                return keyed.sorted { ($0.index ?? 0, $0.key) < ($1.index ?? 0, $1.key) }.map(\.frame)
            }
        }

        /// "hero 12.aseprite" and "hero_12" both give 12.
        private static func trailingNumber(in name: String) -> Int? {
            let stem = name.split(separator: ".").first.map(String.init) ?? name
            let digits = stem.reversed().prefix { $0.isNumber }
            return Int(String(digits.reversed()))
        }
    }

    private struct Document: Decodable {
        var frames: Frames
        var meta: Meta?
    }
}
