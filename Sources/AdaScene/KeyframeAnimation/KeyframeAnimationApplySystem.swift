//
//  KeyframeAnimationApplySystem.swift
//  AdaScene
//

import AdaAnimation
import AdaECS
import AdaRender
import AdaTransform
import AdaUtils
import Math

/// Advances ``KeyframeAnimator/localTime`` and writes sampled values to ``Transform`` and ``Camera``.
@PlainSystem
public struct KeyframeAnimationApplySystem: Sendable {

    @Query<Entity, Ref<KeyframeAnimator>>
    private var animators

    @Res
    private var deltaTime: DeltaTime

    public init(world: World) { }

    public func update(context: UpdateContext) async {
        let world = context.world
        // Scheduler's first frame can report a very large delta; clamp to keep playhead stable.
        let dt = max(0, min(deltaTime.deltaTime, 1.0 / 15.0))
        animators.forEach { _, animator in
            var anim = animator.wrappedValue
            guard anim.isPlaying else { return }
            let clip = anim.clip
            anim.localTime += TimeInterval(Double(dt) * anim.speed)
            let localT = keyframeNormalizedLocalTime(
                playhead: anim.localTime,
                duration: clip.duration,
                mode: clip.repeatMode
            )
            // Keep playhead bounded to avoid precision drift on long sessions.
            anim.localTime = localT
            animator.wrappedValue = anim
            for track in clip.tracks {
                applyTrack(track, localTime: localT, world: world)
            }
        }
    }

    private func applyTrack(_ track: KeyframeTrack, localTime: TimeInterval, world: World) {
        switch track {
        case .transformPosition(let vectorTrack):
            guard let entity = world.getEntityByName(vectorTrack.targetEntityName),
                  var transform = world.get(Transform.self, from: entity.id) else { return }
            guard let value = sampleVector3Keyframes(vectorTrack.keyframes, localTime: localTime) else { return }
            transform.position = value
            world.insert(transform, for: entity.id)

        case .transformScale(let vectorTrack):
            guard let entity = world.getEntityByName(vectorTrack.targetEntityName),
                  var transform = world.get(Transform.self, from: entity.id) else { return }
            guard let value = sampleVector3Keyframes(vectorTrack.keyframes, localTime: localTime) else { return }
            transform.scale = value
            world.insert(transform, for: entity.id)

        case .transformRotation(let quatTrack):
            guard let entity = world.getEntityByName(quatTrack.targetEntityName),
                  var transform = world.get(Transform.self, from: entity.id) else { return }
            guard let value = sampleQuaternionKeyframes(quatTrack.keyframes, localTime: localTime) else { return }
            transform.rotation = value
            world.insert(transform, for: entity.id)

        case .cameraOrthographicScale(let scalarTrack):
            guard let entity = world.getEntityByName(scalarTrack.targetEntityName),
                  var camera = world.get(Camera.self, from: entity.id) else { return }
            guard let value = sampleScalarKeyframes(scalarTrack.keyframes, localTime: localTime) else { return }
            if case .orthographic(var orthographic) = camera.projection {
                orthographic.scale = Float(value)
                camera.projection = .orthographic(orthographic)
                world.insert(camera, for: entity.id)
            }
        }
    }
}
