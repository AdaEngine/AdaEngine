@_spi(AdaEngine) import AdaEngine

/// Frame callbacks keep cached playback state outside AdaUI's observable view state.
@MainActor
final class EditorSpriteAnimationPreviewDriver {
    static let entityName = "Sprite animation preview"
    private static let targetExtent: Float = 160

    private weak var world: World?
    private var entityID: Entity.ID?
    private var appliedRevision = -1

    func update(world: World, model: EditorSpriteAnimationEditorModel, deltaTime: Double) {
        if self.world !== world {
            self.world = world
            entityID = world.getEntities().first { $0.name == Self.entityName }?.id
            appliedRevision = -1
        }
        guard let entityID, let entity = world.getEntityByID(entityID) else { return }
        let clip = model.clip
        if appliedRevision != model.previewRevision {
            appliedRevision = model.previewRevision
            // A new component rewinds playback so an edited clip starts from its first frame.
            entity.components[SpriteAnimator.self] = SpriteAnimator(
                animations: model.previewSet.map { AssetHandle($0) },
                initialClip: clip?.name,
                isPlaying: model.isPlaying,
                restartCount: model.restartCount
            )
            fitScale(of: entity, to: clip, in: model.previewSet)
        }
        guard var animator = entity.components[SpriteAnimator.self] else { return }
        if animator.currentClip != clip?.name {
            animator.currentClip = clip?.name
            fitScale(of: entity, to: clip, in: model.previewSet)
        }
        animator.isPlaying = model.isPlaying
        animator.restartCount = model.restartCount
        entity.components[SpriteAnimator.self] = animator
        model.previewStatistics.record(frame: clip == nil ? nil : animator.frameIndex, count: clip?.frames.count ?? 0, deltaTime: deltaTime)
    }

    /// Pixel art is tiny; scale the sprite up by whole factors so its first frame fills the viewport.
    private func fitScale(of entity: Entity, to clip: SpriteAnimationClip?, in set: SpriteAnimationSet?) {
        guard let frame = clip?.frames.first, let size = set?.texture(for: frame)?.size, size.width > 0, size.height > 0 else { return }
        let scale = max(1, (Self.targetExtent / Float(max(size.width, size.height))).rounded(.down))
        entity.components[Transform.self]?.scale = [scale, scale, 1]
    }
}
