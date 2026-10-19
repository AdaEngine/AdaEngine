import AdaAssets
import AdaECS
import AdaRender
import AdaUtils

@PlainSystem
struct SpriteAnimationSystem {
    @Query<Entity, Ref<SpriteAnimator>, Ref<Sprite>> private var animators
    @Res<DeltaTime> private var time
    @EventsSender<SpriteAnimationEvent> private var events

    init(world _: World) {}

    func update(context _: UpdateContext) {
        let delta = Double(time.deltaTime)
        animators.forEach { entity, animator, sprite in
            guard
                let set = animator.wrappedValue.animations?.asset,
                let name = animator.wrappedValue.currentClip,
                let clip = set.clip(named: name)
            else { return }
            for kind in animator.wrappedValue.advance(by: delta, in: clip) {
                events.send(SpriteAnimationEvent(entityID: entity.id, clip: name, kind: kind))
            }
            guard !clip.frames.isEmpty else { return }
            let frame = min(animator.wrappedValue.frameIndex, clip.frames.count - 1)
            let applied = SpriteAnimator.AppliedFrame(clip: name, frame: frame, set: ObjectIdentifier(set))
            guard animator.wrappedValue.appliedFrame != applied, let texture = set.texture(for: clip.frames[frame]) else { return }
            animator.wrappedValue.appliedFrame = applied
            sprite.wrappedValue.texture = AssetHandle(texture)
        }
    }
}
