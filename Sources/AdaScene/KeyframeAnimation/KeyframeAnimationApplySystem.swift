//
//  KeyframeAnimationApplySystem.swift
//  AdaScene
//

import AdaAnimation
import AdaECS
import AdaUtils

/// Advances each ``KeyframeAnimator``'s playhead and applies the interpolated value
/// to the owner entity via ``KeyframeAnimatable/apply(to:in:)``.
@PlainSystem
public struct KeyframeAnimationApplySystem: Sendable {

    @Query<Entity, Ref<KeyframeAnimator>>
    private var animators

    @Res
    private var deltaTime: DeltaTime

    public init(world: World) { }

    public func update(context: UpdateContext) async {
        let world = context.world
        // Clamp large first-frame deltas that can arise from scheduler cold start.
        let dt = max(0, min(deltaTime.deltaTime, 1.0 / 15.0))

        animators.forEach { ownerEntity, animator in
            var anim = animator.wrappedValue
            guard anim.playbackState == .playing else { return }

            // Apply a pending clip-switch request.
            if let requested = anim.requestedClipName {
                if anim.clipsByName[requested] != nil {
                    anim.currentClipName = requested
                    anim.localTime = 0
                }
                anim.requestedClipName = nil
            }

            guard let clipName = anim.currentClipName,
                  let clip = anim.clipsByName[clipName] else {
                anim.playbackState = .stopped
                anim.runToken &+= 1
                animator.wrappedValue = anim
                return
            }

            anim.localTime += TimeInterval(Double(dt) * anim.speed)

            let state = keyframePlaybackState(
                playhead: anim.localTime,
                duration: clip.duration,
                mode: clip.repeatMode
            )

            clip.applyAt(state.localTime, ownerEntity.id, world)

            if state.isFinished {
                anim.playbackState = .stopped
                anim.runToken &+= 1
            }
            animator.wrappedValue = anim
        }
    }
}
