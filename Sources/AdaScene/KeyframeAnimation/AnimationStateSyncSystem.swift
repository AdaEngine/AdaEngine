//
//  AnimationStateSyncSystem.swift
//  AdaScene
//

import AdaECS

/// Assigns the clip for ``AnimationStateController/state`` to ``KeyframeAnimator`` when it differs (e.g. after state or clip map changes).
@PlainSystem(dependencies: [
    .before(KeyframeAnimationApplySystem.self)
])
public struct AnimationStateSyncSystem: Sendable {

    @Query<Entity, Ref<AnimationStateController>, Ref<KeyframeAnimator>>
    private var query

    public init(world: World) { }

    public func update(context: UpdateContext) async {
        query.forEach { _, controller, animator in
            guard let clip = controller.wrappedValue.clipsByState[controller.wrappedValue.state] else {
                return
            }
            var a = animator.wrappedValue
            if a.clip.name != clip.name {
                a.clip = clip
                a.localTime = 0
                a.isPlaying = true
                animator.wrappedValue = a
            }
        }
    }
}
