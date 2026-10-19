import AdaAnimation
import AdaAssets
import AdaECS
import AdaRender
import Foundation

/// Portable mesh alternatives, retaining the base model's node and material ordering.
public struct Model3DSourceLOD: Codable, Equatable, Sendable {
    public var sources: [String]
    public var screenThresholds: [Float]
    public var maximumDistance: Float?
    public var fadeDistance: Float
    public var skeletonCompatible: Bool
    public var animationLOD: Bool

    public init(sources: [String] = [], screenThresholds: [Float] = [], maximumDistance: Float? = nil,
                fadeDistance: Float = 5, skeletonCompatible: Bool = false, animationLOD: Bool = false) {
        self.sources = sources
        self.screenThresholds = screenThresholds
        self.maximumDistance = maximumDistance
        self.fadeDistance = fadeDistance
        self.skeletonCompatible = skeletonCompatible
        self.animationLOD = animationLOD
    }
}

/// A portable model reference that preserves imported hierarchy, materials and animation.
/// ``Model3DPlugin`` loads the asset and creates an instance beneath the owning entity.
@Component
public struct Model3DSource: Codable, Equatable, Sendable {
    public var source: String
    public var animation: String
    public var autoplay: Bool
    public var repeats: Bool
    /// Optional authored pose graph. When present it takes precedence over the single clip.
    public var animationGraph: AnimationGraph?
    public var lod: Model3DSourceLOD?
    /// Import settings for MagicaVoxel (`.vox`) sources; ignored for other formats.
    public var voxel: VoxelImportSettings?
    /// Morph target weights by target name, applied to every mesh of the model that has a target of that name. They are the
    /// weights the instance starts with and keeps unless an animation clip animates that mesh's weights.
    public var morphWeights: [String: Float]

    public init(source: String = "", animation: String = "", autoplay: Bool = false, repeats: Bool = true,
                animationGraph: AnimationGraph? = nil, lod: Model3DSourceLOD? = nil, voxel: VoxelImportSettings? = nil,
                morphWeights: [String: Float] = [:]) {
        self.morphWeights = morphWeights
        self.voxel = voxel
        self.source = source
        self.animation = animation
        self.autoplay = autoplay
        self.repeats = repeats
        self.animationGraph = animationGraph
        self.lod = lod
    }

    private enum CodingKeys: CodingKey {
        case source, animation, autoplay, repeats, animationGraph, lod, voxel, morphWeights
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(String.self, forKey: .source)
        animation = try container.decode(String.self, forKey: .animation)
        autoplay = try container.decode(Bool.self, forKey: .autoplay)
        repeats = try container.decode(Bool.self, forKey: .repeats)
        animationGraph = try container.decodeIfPresent(AnimationGraph.self, forKey: .animationGraph)
        lod = try container.decodeIfPresent(Model3DSourceLOD.self, forKey: .lod)
        voxel = try container.decodeIfPresent(VoxelImportSettings.self, forKey: .voxel)
        // Scenes written before morph targets have no weights.
        morphWeights = try container.decodeIfPresent([String: Float].self, forKey: .morphWeights) ?? [:]
    }

    /// The path the model asset is loaded from: ``source`` plus the import settings of a `.vox` file as an asset query.
    public var assetPath: String {
        guard let voxel, !voxel.isDefault, !source.isEmpty, !source.contains("#"),
            source.lowercased().hasSuffix(".vox"), !voxel.assetQuery.isEmpty
        else {
            return source
        }
        return "\(source)#\(voxel.assetQuery)"
    }

    /// Installs an already loaded asset. Used by hosts that prepare models before their first frame.
    /// An invalid clip fails before creating entities. Each call creates an independent animation player.
    @discardableResult
    public func instantiate(_ model: ModelAsset3D, alternatives: [ModelAsset3D] = [], in world: World, under owner: Entity) throws -> Entity {
        if let lod, alternatives.count != lod.sources.count {
            throw AssetError.message("Model LOD alternatives have not been loaded.")
        }
        guard animationGraph != nil || animation.isEmpty || model.animationClips.contains(where: { $0.name == animation }) else {
            throw AssetError.message("Model has no animation named '\(animation)'.")
        }
        if let animationGraph {
            guard let rig = model.animationRig else { throw AssetError.message("Model has no animation rig.") }
            try animationGraph.validate(rig: rig, clips: model.animationClips)
        }
        let root = model.instantiate(in: world)
        if !morphWeights.isEmpty {
            var pending = [root]
            while let node = pending.popLast() {
                if var component = node.components[MorphWeights3DComponent.self] {
                    var changed = false
                    for (name, weight) in morphWeights where weight.isFinite {
                        if component.setWeight(weight, named: name) { changed = true }
                    }
                    if changed { node.components[MorphWeights3DComponent.self] = component }
                }
                pending.append(contentsOf: node.children)
            }
        }
        if var animationComponent = root.components[ModelAnimation3DComponent.self], animationGraph != nil || !animation.isEmpty {
            if let animationGraph {
                try animationComponent.player.play(animationGraph, transitionDuration: 0)
            } else {
                try animationComponent.player.play(animation, transitionDuration: 0)
            }
            animationComponent.player.isPlaying = autoplay
            animationComponent.player.repeats = repeats
            if lod?.animationLOD == true { animationComponent.evaluationLOD = AnimationLOD3DSettings() }
            root.components[ModelAnimation3DComponent.self] = animationComponent
        }
        if var voxelPlayback = root.components[VoxelAnimationPlayback3DComponent.self] {
            voxelPlayback.isPlaying = autoplay
            voxelPlayback.repeats = repeats
            root.components[VoxelAnimationPlayback3DComponent.self] = voxelPlayback
        }
        owner.addChild(root)
        if let lod {
            var pending = root.children
            while let node = pending.popLast() {
                if let binding = node.components[ModelNode3DComponent.self], model.nodes.indices.contains(binding.nodeIndex),
                    let meshIndex = model.nodes[binding.nodeIndex].meshIndex,
                    alternatives.allSatisfy({ $0.meshes.indices.contains(meshIndex) }) {
                    var value = MeshLOD3DComponent(alternatives: alternatives.map { $0.meshes[meshIndex] },
                                                   screenThresholds: lod.screenThresholds, maximumDistance: lod.maximumDistance,
                                                   fadeDistance: lod.fadeDistance)
                    value.skeletonCompatible = lod.skeletonCompatible
                    node.components[MeshLOD3DComponent.self] = value
                }
                pending.append(contentsOf: node.children)
            }
        }
        owner.components[Model3DSourceState.self] = .init(reference: self, rootEntityID: root.id)
        return root
    }
}

/// Runtime status of a model reference. Generated nodes are not part of the authored scene.
public struct Model3DSourceState: Component {
    public let reference: Model3DSource
    public let rootEntityID: Entity.ID?
    public let error: String?

    public init(reference: Model3DSource, rootEntityID: Entity.ID? = nil, error: String? = nil) {
        self.reference = reference
        self.rootEntityID = rootEntityID
        self.error = error
    }
}

/// Loads changed references asynchronously, applying hierarchy changes through deferred world commands.
@PlainSystem
public struct Model3DSourceSystem {
    @Query<Entity, Model3DSource> private var sources
    @Query<Entity, Model3DSourceState> private var instances
    @Commands private var commands

    public init(world _: World) {}

    public func update(context _: UpdateContext) async {
        var pending: [(Entity.ID, Model3DSource)] = []
        sources.forEach { entity, reference in
            let state = entity.components[Model3DSourceState.self]
            if state?.reference != reference { pending.append((entity.id, reference)) }
        }
        instances.forEach { entity, state in
            guard entity.components[Model3DSource.self] == nil else {
                return
            }
            let id = entity.id
            commands.queue.push { world in
                guard let owner = world.getEntityByID(id), owner.components[Model3DSource.self] == nil else {
                    return
                }
                if let rootID = state.rootEntityID { world.removeEntity(rootID, recursively: true) }
                owner.components[Model3DSourceState.self] = nil
            }
        }
        for (id, reference) in pending {
            let result: Result<(ModelAsset3D?, [ModelAsset3D]), AssetError>
            do {
                let model = reference.source.isEmpty ? nil : try await AssetsManager.load(ModelAsset3D.self, at: reference.assetPath).asset
                var alternatives: [ModelAsset3D] = []
                for source in reference.lod?.sources ?? [] {
                    guard let level = try await AssetsManager.load(ModelAsset3D.self, at: source).asset else {
                        throw AssetError.message("Model LOD has not loaded: \(source)")
                    }
                    alternatives.append(level)
                }
                result = .success((model, alternatives))
            } catch {
                result = .failure(.message(error.localizedDescription))
            }
            commands.queue.push { world in
                guard let owner = world.getEntityByID(id), owner.components[Model3DSource.self] == reference,
                    owner.components[Model3DSourceState.self]?.reference != reference else { return }
                if let rootID = owner.components[Model3DSourceState.self]?.rootEntityID {
                    world.removeEntity(rootID, recursively: true)
                }
                do {
                    let (model, alternatives) = try result.get()
                    if let model {
                        try reference.instantiate(model, alternatives: alternatives, in: world, under: owner)
                    } else {
                        owner.components[Model3DSourceState.self] = .init(reference: reference)
                    }
                } catch {
                    owner.components[Model3DSourceState.self] = .init(reference: reference, error: error.localizedDescription)
                }
            }
        }
    }
}
