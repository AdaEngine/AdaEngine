//
//  AnimationStateController.swift
//  AdaScene
//

import AdaAnimation
import AdaECS

/// Maps named states to keyframe clips; use with ``KeyframeAnimator`` and ``AnimationStateSyncSystem``.
@Component
public struct AnimationStateController: Sendable {

    /// Current logical state (e.g. `"idle"`, `"intro"`).
    public var state: String

    /// Clip to play when entering a state.
    public var clipsByState: [String: KeyframeClip]

    public init(state: String = "", clipsByState: [String: KeyframeClip] = [:]) {
        self.state = state
        self.clipsByState = clipsByState
    }
}
