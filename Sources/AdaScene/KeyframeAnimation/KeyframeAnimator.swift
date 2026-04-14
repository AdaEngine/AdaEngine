//
//  KeyframeAnimator.swift
//  AdaScene
//

import AdaAnimation
import AdaECS
import AdaUtils

/// Plays a ``KeyframeClip`` on the world, updating named entities each frame.
@Component
public struct KeyframeAnimator: Sendable {

    /// Timeline data (tracks reference entities by ``Entity/name``).
    public var clip: KeyframeClip

    /// Current position along the clip in seconds.
    public var localTime: TimeInterval

    /// Multiplier for frame delta while ``isPlaying``.
    public var speed: Double

    public var isPlaying: Bool

    public init(
        clip: KeyframeClip,
        localTime: TimeInterval = 0,
        speed: Double = 1,
        isPlaying: Bool = true
    ) {
        self.clip = clip
        self.localTime = localTime
        self.speed = speed
        self.isPlaying = isPlaying
    }
}
