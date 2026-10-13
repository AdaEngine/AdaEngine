@_spi(AdaEngine) import AdaEngine
import Observation

/// UI telemetry has its own observation boundary; rendering continues every frame.
@Observable
@MainActor
final class EditorParticlePreviewStatistics {
    private(set) var particleCount = 0
    @ObservationIgnored private var elapsed: Double = 0
    private static let interval: Double = 0.25

    func record(particleCount: Int, deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else {
            return
        }
        elapsed += deltaTime
        guard elapsed >= Self.interval else {
            return
        }
        elapsed.formTruncatingRemainder(dividingBy: Self.interval)
        if self.particleCount != particleCount { self.particleCount = particleCount }
    }
}

/// Frame callbacks keep cached playback state outside AdaUI's observable view state.
@MainActor
final class EditorParticlePreviewDriver {
    private weak var world: World?
    private var entityID: Entity.ID?
    private var appliedRevision = -1

    func update(world: World, model: EditorParticleEffectEditorModel, deltaTime: Double) {
        if self.world !== world {
            self.world = world
            entityID = world.getEntities().first { $0.name == "Particle preview" }?.id
            appliedRevision = -1
        }
        guard let entityID, let entity = world.getEntityByID(entityID) else {
            return
        }
        if appliedRevision != model.previewRevision, let effect = model.previewEffect {
            entity.components[ParticleEmitter.self]?.effect = AssetHandle(effect)
            appliedRevision = model.previewRevision
        }
        if entity.components[ParticleEmitter.self]?.isPaused != !model.isPlaying {
            entity.components[ParticleEmitter.self]?.isPaused = !model.isPlaying
        }
        if entity.components[ParticleEmitter.self]?.restartCount != model.restartCount {
            entity.components[ParticleEmitter.self]?.restartCount = model.restartCount
        }
        model.previewStatistics.record(particleCount: entity.components[ParticleEmitter.self]?.particleCount ?? 0, deltaTime: deltaTime)
    }
}

struct EditorParticleLiveCount: View {
    let statistics: EditorParticlePreviewStatistics

    var body: some View {
        Text("\(statistics.particleCount) particles")
            .font(.system(size: 11))
            .frame(width: 112, alignment: .trailing)
            .accessibilityIdentifier("AdaEditor.ParticleFX.Count")
    }
}
