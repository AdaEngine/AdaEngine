import AdaAssets
import AdaECS
import AdaUtils

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

/// Plays clips of a ``SpriteAnimationSet`` on the entity's ``Sprite``. The animator owns `Sprite.texture` while a clip is selected.
///
/// Script and inspector controls are plain fields: assign `currentClip` to switch clips, `isPlaying` to pause or resume,
/// `speed` to scale time, and increment `restartCount` to rewind the selected clip.
@Component
public struct SpriteAnimator: Codable, Sendable {
    public var animations: AssetHandle<SpriteAnimationSet>?
    /// Name of the selected clip. Changing it starts that clip from its first frame; unknown names show nothing new.
    public var currentClip: String? {
        didSet {
            guard currentClip != oldValue else { return }
            rewind()
        }
    }

    public var isPlaying: Bool
    /// Playback rate multiplier; negative and non-finite values are treated as zero.
    public var speed: Float
    /// Increment to replay the selected clip from its first frame.
    public var restartCount: Int

    private static let boundaryTolerance = 1e-6

    public private(set) var frameIndex: Int = 0
    var elapsed: Double = 0
    var isReversed: Bool = false
    var appliedRestartCount: Int
    var appliedFrame: AppliedFrame?

    struct AppliedFrame: Equatable, Sendable {
        var clip: String
        var frame: Int
        var set: ObjectIdentifier
    }

    @AdaScriptInit
    public init(
        animations: AssetHandle<SpriteAnimationSet>? = nil,
        initialClip: String? = nil,
        isPlaying: Bool = true,
        speed: Float = 1,
        restartCount: Int = 0
    ) {
        self.animations = animations
        self.currentClip = initialClip ?? animations?.asset?.clips.first?.name
        self.isPlaying = isPlaying
        self.speed = speed
        self.restartCount = restartCount
        self.appliedRestartCount = restartCount
    }

    private enum CodingKeys: CodingKey { case animations, currentClip, isPlaying, speed, restartCount }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            animations: try values.decodeIfPresent(AssetHandle<SpriteAnimationSet>.self, forKey: .animations),
            initialClip: try values.decodeIfPresent(String.self, forKey: .currentClip),
            isPlaying: try values.decodeIfPresent(Bool.self, forKey: .isPlaying) ?? true,
            speed: try values.decodeIfPresent(Float.self, forKey: .speed) ?? 1,
            restartCount: try values.decodeIfPresent(Int.self, forKey: .restartCount) ?? 0
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(animations, forKey: .animations)
        try values.encodeIfPresent(currentClip, forKey: .currentClip)
        try values.encode(isPlaying, forKey: .isPlaying)
        try values.encode(speed, forKey: .speed)
        try values.encode(restartCount, forKey: .restartCount)
    }

    /// Selects a clip and starts it. Selecting the clip that is already current keeps its frame unless `restart` is set.
    public mutating func play(_ name: String, restart: Bool = false) {
        if currentClip == name, restart { rewind() }
        currentClip = name
        isPlaying = true
    }

    /// Keeps the selected clip and frame, and stops advancing.
    public mutating func pause() {
        isPlaying = false
    }

    /// Stops and returns to the first frame of the selected clip.
    public mutating func stop() {
        isPlaying = false
        rewind()
    }

    private mutating func rewind() {
        frameIndex = 0
        elapsed = 0
        isReversed = false
    }

    /// Advances playback of `clip` by `delta` seconds and reports what happened, in order.
    mutating func advance(by delta: Double, in clip: SpriteAnimationClip) -> [SpriteAnimationEvent.Kind] {
        if appliedRestartCount != restartCount {
            appliedRestartCount = restartCount
            rewind()
        }
        guard isPlaying, !clip.frames.isEmpty else { return [] }
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
            // Scheduler time steps are Float, so a frame boundary can land a few nanoseconds short.
            guard elapsed + Self.boundaryTolerance >= length else { break }
            elapsed = max(0, elapsed - length)
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
