import Math

/// How a ``SpriteAnimationClip`` behaves after its last frame.
public enum SpriteAnimationPlaybackMode: String, Codable, Sendable, CaseIterable {
    /// Play to the last frame, hold it and stop.
    case once
    /// Restart from the first frame.
    case loop
    /// Reverse direction at both ends.
    case pingPong
}

/// One cell of a ``TextureAtlas`` grid shown for a relative duration.
public struct SpriteAnimationFrame: Codable, Sendable, Equatable {
    /// Grid position in the atlas, as used by ``TextureAtlas/textureSlice(at:)``.
    public var atlasCoordinates: PointInt
    /// Length of this frame as a multiple of one frame at the clip's `framesPerSecond`.
    public var duration: Float
    /// Optional name delivered as ``SpriteAnimationEvent/Kind-swift.enum/marker(_:)`` when the frame is entered.
    public var marker: String?

    public init(atlasCoordinates: PointInt, duration: Float = 1, marker: String? = nil) {
        self.atlasCoordinates = atlasCoordinates
        self.duration = duration
        self.marker = marker
    }

    private enum CodingKeys: CodingKey { case atlasCoordinates, duration, marker }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            atlasCoordinates: try values.decode(PointInt.self, forKey: .atlasCoordinates),
            duration: try values.decodeIfPresent(Float.self, forKey: .duration) ?? 1,
            marker: try values.decodeIfPresent(String.self, forKey: .marker)
        )
    }
}

/// A named sequence of atlas cells.
public struct SpriteAnimationClip: Codable, Sendable, Equatable {
    public var name: String
    public var frames: [SpriteAnimationFrame]
    public var framesPerSecond: Float
    public var playbackMode: SpriteAnimationPlaybackMode

    public init(
        name: String,
        frames: [SpriteAnimationFrame],
        framesPerSecond: Float = 12,
        playbackMode: SpriteAnimationPlaybackMode = .loop
    ) {
        self.name = name
        self.frames = frames
        self.framesPerSecond = framesPerSecond
        self.playbackMode = playbackMode
    }

    /// Frames laid out left to right in one atlas row.
    public static func row(
        _ name: String,
        row: Int,
        columns: Range<Int>,
        framesPerSecond: Float = 12,
        playbackMode: SpriteAnimationPlaybackMode = .loop
    ) -> SpriteAnimationClip {
        SpriteAnimationClip(
            name: name,
            frames: columns.map { SpriteAnimationFrame(atlasCoordinates: PointInt(x: $0, y: row)) },
            framesPerSecond: framesPerSecond,
            playbackMode: playbackMode
        )
    }

    /// Seconds a frame stays visible; zero when the clip cannot advance.
    func secondsPerFrame(at index: Int) -> Double {
        guard frames.indices.contains(index), framesPerSecond.isFinite, framesPerSecond > 0, frames[index].duration.isFinite else {
            return 0
        }
        return Double(max(frames[index].duration, 0)) / Double(framesPerSecond)
    }
}
