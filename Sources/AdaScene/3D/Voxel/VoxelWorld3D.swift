//
//  VoxelWorld3D.swift
//  AdaEngine
//

import AdaAssets
import AdaECS
@_spi(Internal) import AdaRender
import AdaTransform
import Math

/// A dynamic, editable voxel world rendered as one mesh entity per 32³ chunk below the owning entity.
///
/// Edit voxels through ``storage``; ``VoxelWorldMeshing3DSystem`` rebuilds dirty chunks, at most
/// ``meshingBudget`` per update, so large edits spread across frames.
public struct VoxelWorld3DComponent: Component {
    /// Shared chunk storage. Editing it from any thread is safe.
    public let storage: VoxelWorldStorage
    public var palette: VOXPalette
    /// Edge length of one voxel in world units.
    public var voxelSize: Float
    public var meshingStrategy: VoxelMeshingOptions.Strategy
    public var bakesAmbientOcclusion: Bool
    public var castShadows: Bool
    public var receiveShadows: Bool
    /// Maximum number of chunks remeshed per update.
    public var meshingBudget: Int

    public init(
        storage: VoxelWorldStorage = VoxelWorldStorage(),
        palette: VOXPalette = .fallback,
        voxelSize: Float = 0.1,
        meshingStrategy: VoxelMeshingOptions.Strategy = .greedy,
        bakesAmbientOcclusion: Bool = true,
        castShadows: Bool = true,
        receiveShadows: Bool = true,
        meshingBudget: Int = 4
    ) {
        self.storage = storage
        self.palette = palette
        self.voxelSize = voxelSize
        self.meshingStrategy = meshingStrategy
        self.bakesAmbientOcclusion = bakesAmbientOcclusion
        self.castShadows = castShadows
        self.receiveShadows = receiveShadows
        self.meshingBudget = meshingBudget
    }

    var meshingOptions: VoxelMeshingOptions {
        VoxelMeshingOptions(voxelSize: voxelSize, strategy: meshingStrategy, bakesAmbientOcclusion: bakesAmbientOcclusion)
    }

    /// Voxel coordinate containing a point in the world's local space.
    public func voxelCoordinate(forLocalPoint point: Vector3) -> SIMD3<Int> {
        SIMD3(
            Int((point.x / voxelSize).rounded(.down)),
            Int((point.y / voxelSize).rounded(.down)),
            Int((point.z / voxelSize).rounded(.down))
        )
    }
}

/// Marks an entity as one chunk mesh of a voxel world.
public struct VoxelChunk3DComponent: Component {
    public let coordinate: VoxelChunkCoordinate

    public init(coordinate: VoxelChunkCoordinate) {
        self.coordinate = coordinate
    }
}

/// Rebuilds the meshes of dirty voxel chunks. Meshing runs in parallel off the main world; entity changes are
/// queued as world commands.
@PlainSystem
public struct VoxelWorldMeshing3DSystem {
    @Query<Entity, VoxelWorld3DComponent> private var worlds
    @Commands private var commands

    public init(world _: World) {}

    private struct MeshedChunk: Sendable {
        let coordinate: VoxelChunkCoordinate
        let descriptor: MeshDescriptor?
    }

    private struct MeshingJob: Sendable {
        let coordinate: VoxelChunkCoordinate
        let grid: VoxelGrid
        let region: VoxelMeshingRegion
        let palette: VOXPalette
        let options: VoxelMeshingOptions
    }

    private static func mesh(_ job: MeshingJob) -> MeshedChunk {
        let coordinate = job.coordinate
        return MeshedChunk(
            coordinate: coordinate,
            descriptor: VoxelMesher.makeDescriptor(
                grid: job.grid,
                palette: job.palette,
                options: job.options,
                region: job.region,
                name: "VoxelChunk \(coordinate.x),\(coordinate.y),\(coordinate.z)"
            )
        )
    }

    /// Meshes chunks in parallel. Kept separate from `update` because the coroutine splitter of Swift 6.2.3 crashes on
    /// a task-group closure inside the system's async method.
    private static func mesh(_ jobs: [MeshingJob]) async -> [MeshedChunk] {
        await withTaskGroup(of: MeshedChunk.self) { group in
            for job in jobs {
                group.addTask { mesh(job) }
            }
            var chunks: [MeshedChunk] = []
            for await chunk in group {
                chunks.append(chunk)
            }
            return chunks
        }
    }

    public func update(context _: UpdateContext) async {
        var pending: [(owner: Entity.ID, component: VoxelWorld3DComponent)] = []
        worlds.forEach { entity, component in
            if component.storage.hasDirtyChunks {
                pending.append((entity.id, component))
            }
        }

        for (ownerID, component) in pending {
            let coordinates = component.storage.takeDirtyChunks(limit: component.meshingBudget)
            guard !coordinates.isEmpty else {
                continue
            }

            let jobs = coordinates.map { coordinate in
                let snapshot = component.storage.paddedSnapshot(of: coordinate)
                return MeshingJob(
                    coordinate: coordinate,
                    grid: snapshot.grid,
                    region: snapshot.region,
                    palette: component.palette,
                    options: component.meshingOptions
                )
            }
            let meshed = await Self.mesh(jobs)

            let result = meshed
            commands.queue.push { world in
                guard let owner = world.getEntityByID(ownerID), let current = owner.components[VoxelWorld3DComponent.self] else {
                    return
                }
                Self.apply(result, to: owner, component: current, in: world)
            }
        }
    }

    private static func apply(_ chunks: [MeshedChunk], to owner: Entity, component: VoxelWorld3DComponent, in world: World) {
        let storage = component.storage
        let device = unsafe RenderEngine.shared.renderDevice
        let material = chunkMaterial()
        let chunkExtent = Float(VoxelWorldStorage.chunkSize) * component.voxelSize

        for chunk in chunks {
            let existing = storage.chunkEntity(for: chunk.coordinate).flatMap { world.getEntityByID($0) }
            guard let descriptor = chunk.descriptor else {
                if let existing {
                    world.removeEntity(existing.id, recursively: true)
                }
                storage.setChunkEntity(nil, for: chunk.coordinate)
                continue
            }

            let mesh = Mesh.generate(from: [descriptor], renderDevice: device)
            let meshComponent = Mesh3DComponent(
                mesh: mesh,
                materials: [material],
                castShadows: component.castShadows,
                receiveShadows: component.receiveShadows
            )
            let position = Vector3(
                Float(chunk.coordinate.x) * chunkExtent,
                Float(chunk.coordinate.y) * chunkExtent,
                Float(chunk.coordinate.z) * chunkExtent
            )

            if let existing {
                existing.components[Mesh3DComponent.self] = meshComponent
                existing.components[Transform.self] = Transform(position: position)
            } else {
                let entity = world.spawn("VoxelChunk \(chunk.coordinate.x),\(chunk.coordinate.y),\(chunk.coordinate.z)")
                entity.components[Transform.self] = Transform(position: position)
                entity.components[Mesh3DComponent.self] = meshComponent
                entity.components[VoxelChunk3DComponent.self] = VoxelChunk3DComponent(coordinate: chunk.coordinate)
                owner.addChild(entity)
                storage.setChunkEntity(entity.id, for: chunk.coordinate)
            }
        }
    }

    /// One diffuse material shared by all chunks; palette colors live in vertex colors.
    private static func chunkMaterial() -> PBRMaterial {
        let material = PBRMaterial()
        material.metallicFactor = 0
        material.roughnessFactor = 0.85
        return material
    }
}
