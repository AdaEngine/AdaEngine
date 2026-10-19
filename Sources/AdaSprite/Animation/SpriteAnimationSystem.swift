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
            guard let clip = animator.wrappedValue.activeClip else { return }
            let kinds = animator.wrappedValue.advance(by: delta)
            for kind in kinds {
                events.send(SpriteAnimationEvent(entityID: entity.id, clip: clip.name, kind: kind))
            }
            apply(clip: clip, animator: animator, sprite: sprite)
        }
    }

    private func apply(clip: SpriteAnimationClip, animator: Ref<SpriteAnimator>, sprite: Ref<Sprite>) {
        guard let atlas = animator.wrappedValue.atlas?.asset, !clip.frames.isEmpty else { return }
        let atlasID = ObjectIdentifier(atlas)
        let frame = min(animator.wrappedValue.frameIndex, clip.frames.count - 1)
        let applied = SpriteAnimator.AppliedFrame(clip: clip.name, frame: frame, atlas: atlasID)
        guard animator.wrappedValue.appliedFrame != applied else { return }

        let coordinates = clip.frames.map(\.atlasCoordinates)
        var cache = animator.wrappedValue.sliceCache[clip.name]
        if cache?.atlas != atlasID || cache?.coordinates != coordinates {
            cache = SpriteAnimator.CachedSlices(
                atlas: atlasID,
                coordinates: coordinates,
                slices: coordinates.map { atlas.textureSlice(at: $0) }
            )
        }
        guard let slices = cache?.slices, slices.indices.contains(frame) else { return }
        animator.wrappedValue.sliceCache[clip.name] = cache
        animator.wrappedValue.appliedFrame = applied
        sprite.wrappedValue.texture = AssetHandle(slices[frame])
    }
}
