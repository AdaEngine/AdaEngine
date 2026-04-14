//
//  KeyframeInputTriggerSystem.swift
//  AdaScene
//

import AdaECS
import AdaInput

/// Applies ``KeyframeAnimationInputBindings`` using ``KeyEvent`` down events from ``Input``.
@PlainSystem(dependencies: [
    .before(AnimationStateSyncSystem.self)
])
public struct KeyframeInputTriggerSystem: Sendable {

    @Query<Entity, Ref<KeyframeAnimationInputBindings>, Ref<AnimationStateController>>
    private var query

    @Res
    private var input: Input

    public init(world: World) { }

    public func update(context: UpdateContext) async {
        let events = input.getInputEvents()
        guard !events.isEmpty else { return }

        var keyDown: Set<KeyCode> = []
        for event in events {
            guard let key = event as? KeyEvent, key.status == .down, !key.isRepeated else {
                continue
            }
            keyDown.insert(key.keyCode)
        }
        guard !keyDown.isEmpty else { return }

        query.forEach { _, bindings, controller in
            for binding in bindings.wrappedValue.bindings where keyDown.contains(binding.keyCode) {
                var c = controller.wrappedValue
                c.state = binding.targetState
                controller.wrappedValue = c
            }
        }
    }
}
