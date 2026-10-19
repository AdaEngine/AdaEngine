import AdaAssets
import AdaECS
import AdaRender
import AdaUtils
import Math

/// Notification produced while a ``SpriteAnimator`` plays. Receive with `Events<SpriteAnimationEvent>`.
public struct SpriteAnimationEvent: Event, Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// A new frame became visible.
        case frameChanged(Int)
        /// The frame carrying this marker became visible.
        case marker(String)
        /// A looping or ping-pong clip completed one cycle.
        case looped
        /// A ``SpriteAnimationPlaybackMode/once`` clip reached its last frame.
        case finished
    }

    public let entityID: Entity.ID
    public let clip: String
    public let kind: Kind

    public init(entityID: Entity.ID, clip: String, kind: Kind) {
        self.entityID = entityID
        self.clip = clip
        self.kind = kind
    }
}

/// Plays atlas-grid clips on the entity's ``Sprite``. The animator owns `Sprite.texture` while a clip is selected.
@Component
public struct SpriteAnimator: Codable, Sendable {
    public var atlas: AssetHandle<TextureAtlas>?
    public var clips: [SpriteAnimationClip]
    /// Name of the selected clip. Use ``play(_:restart:)`` to change it.
    public private(set) var currentClip: String?
    public var isPlaying: Bool
    /// Playback rate multiplier; negative and non-finite values are treated as zero.
    public var speed: Float

    public private(set) var frameIndex: Int = 0
    var elapsed: Double = 0
    var isReversed: Bool = false
    var appliedFrame: AppliedFrame?
    var sliceCache: [String: CachedSlices] = [:]

    struct AppliedFrame: Equatable, Sendable {
        var clip: String
        var frame: Int
        var atlas: ObjectIdentifier
    }

    struct CachedSlices: Sendable {
        var atlas: ObjectIdentifier
        var coordinates: [PointInt]
        var slices: [TextureAtlas.Slice]
    }

    public init(
        atlas: AssetHandle<TextureAtlas>? = nil,
        clips: [SpriteAnimationClip] = [],
        initialClip: String? = nil,
        isPlaying: Bool = true,
        speed: Float = 1
    ) {
        self.atlas = atlas
        self.clips = clips
        self.currentClip = initialClip ?? clips.first?.name
        self.isPlaying = isPlaying
        self.speed = speed
    }

    private enum CodingKeys: CodingKey { case atlas, clips, currentClip, isPlaying, speed }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            atlas: try values.decodeIfPresent(AssetHandle<TextureAtlas>.self, forKey: .atlas),
            clips: try values.decodeIfPresent([SpriteAnimationClip].self, forKey: .clips) ?? [],
            initialClip: try values.decodeIfPresent(String.self, forKey: .currentClip),
            isPlaying: try values.decodeIfPresent(Bool.self, forKey: .isPlaying) ?? true,
            speed: try values.decodeIfPresent(Float.self, forKey: .speed) ?? 1
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(atlas, forKey: .atlas)
        try values.encode(clips, forKey: .clips)
        try values.encodeIfPresent(currentClip, forKey: .currentClip)
        try values.encode(isPlaying, forKey: .isPlaying)
        try values.encode(speed, forKey: .speed)
    }

    /// Selects a clip and starts it. Calling with the clip already selected keeps the current frame unless `restart` is set.
    /// Unknown names are ignored.
    public mutating func play(_ name: String, restart: Bool = false) {
        guard clips.contains(where: { $0.name == name }) else { return }
        if currentClip != name || restart {
            currentClip = name
            frameIndex = 0
            elapsed = 0
            isReversed = false
        }
        isPlaying = true
    }

    /// Keeps the selected clip and frame, and stops advancing.
    public mutating func pause() {
        isPlaying = false
    }

    /// Stops and returns to the first frame of the selected clip.
    public mutating func stop() {
        isPlaying = false
        frameIndex = 0
        elapsed = 0
        isReversed = false
    }

    var activeClip: SpriteAnimationClip? {
        guard let currentClip else { return nil }
        return clips.first { $0.name == currentClip }
    }

    /// Advances playback by `delta` seconds and reports what happened, in order.
    mutating func advance(by delta: Double) -> [SpriteAnimationEvent.Kind] {
        guard isPlaying, let clip = activeClip, !clip.frames.isEmpty else { return [] }
        if frameIndex >= clip.frames.count { frameIndex = clip.frames.count - 1 }
        let rate = speed.isFinite ? Double(max(speed, 0)) : 0
        guard delta.isFinite, delta > 0, rate > 0 else { return [] }

        var events: [SpriteAnimationEvent.Kind] = []
        elapsed += delta * rate
        // Bounds a clip whose frames are all (near) zero length; leftover time is dropped.
        var budget = 4096
        while budget > 0 {
            budget -= 1
            let length = clip.secondsPerFrame(at: frameIndex)
            guard length > 0 else {
                elapsed = 0
                break
            }
            guard elapsed >= length else { break }
            elapsed -= length
            if !step(clip, into: &events) { break }
        }
        if budget == 0 { elapsed = 0 }
        return events
    }

    /// Returns false when playback ended.
    private mutating func step(_ clip: SpriteAnimationClip, into events: inout [SpriteAnimationEvent.Kind]) -> Bool {
        let last = clip.frames.count - 1
        var next = frameIndex + (isReversed ? -1 : 1)
        switch clip.playbackMode {
        case .once:
            guard next <= last else {
                isPlaying = false
                elapsed = 0
                events.append(.finished)
                return false
            }
        case .loop:
            if next > last {
                next = 0
                events.append(.looped)
            }
        case .pingPong:
            if last == 0 {
                next = 0
                events.append(.looped)
            } else if next > last {
                isReversed = true
                next = last - 1
            } else if next < 0 {
                isReversed = false
                next = 1
                events.append(.looped)
            }
        }
        if next != frameIndex {
            frameIndex = next
            events.append(.frameChanged(next))
        }
        if let marker = clip.frames[next].marker {
            events.append(.marker(marker))
        }
        return true
    }
}
