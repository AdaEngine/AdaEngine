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

/// One image region shown for a relative duration. Exactly one of `atlasCoordinates` and `region` selects the pixels.
public struct SpriteAnimationFrame: Codable, Sendable, Equatable {
    /// Cell in the set's grid (``SpriteAnimationSetDescriptor/cellSize``).
    public var atlasCoordinates: PointInt?
    /// Pixel rectangle from the image's top-left corner, as written by packed sprite sheets such as Aseprite's.
    public var region: RectInt?
    /// Length of this frame as a multiple of one frame at the clip's `framesPerSecond`.
    public var duration: Float
    /// Optional name delivered as ``SpriteAnimationEvent/Kind-swift.enum/marker(_:)`` when the frame is entered.
    public var marker: String?

    public init(atlasCoordinates: PointInt, duration: Float = 1, marker: String? = nil) {
        self.atlasCoordinates = atlasCoordinates
        self.region = nil
        self.duration = duration
        self.marker = marker
    }

    public init(region: RectInt, duration: Float = 1, marker: String? = nil) {
        self.atlasCoordinates = nil
        self.region = region
        self.duration = duration
        self.marker = marker
    }

    private enum CodingKeys: CodingKey { case atlasCoordinates, region, duration, marker }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.atlasCoordinates = try values.decodeIfPresent(PointInt.self, forKey: .atlasCoordinates)
        self.region = try values.decodeIfPresent(RectInt.self, forKey: .region)
        self.duration = try values.decodeIfPresent(Float.self, forKey: .duration) ?? 1
        self.marker = try values.decodeIfPresent(String.self, forKey: .marker)
    }
}

/// A named sequence of frames.
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

    private enum CodingKeys: CodingKey { case name, frames, framesPerSecond, playbackMode }

    /// Hand-written resources may omit the rate and mode.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try values.decode(String.self, forKey: .name),
            frames: try values.decodeIfPresent([SpriteAnimationFrame].self, forKey: .frames) ?? [],
            framesPerSecond: try values.decodeIfPresent(Float.self, forKey: .framesPerSecond) ?? 12,
            playbackMode: try values.decodeIfPresent(SpriteAnimationPlaybackMode.self, forKey: .playbackMode) ?? .loop
        )
    }

    /// Frames laid out left to right in one grid row.
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
