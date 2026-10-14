//
//  VoxelWorld3D.swift
//  AdaEngine
//

import AdaAssets
import AdaECS
import AdaPhysics
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
    /// Builds a static physics collider (merged boxes) for every chunk. Requires ``Physics3DPlugin``.
    public var generatesColliders: Bool
    public var colliderMaterial: PhysicsMaterial?

    public init(
        storage: VoxelWorldStorage = VoxelWorldStorage(),
        palette: VOXPalette = .fallback,
        voxelSize: Float = 0.1,
        meshingStrategy: VoxelMeshingOptions.Strategy = .greedy,
        bakesAmbientOcclusion: Bool = true,
        castShadows: Bool = true,
        receiveShadows: Bool = true,
        meshingBudget: Int = 4,
        generatesColliders: Bool = false,
        colliderMaterial: PhysicsMaterial? = nil
    ) {
        self.generatesColliders = generatesColliders
        self.colliderMaterial = colliderMaterial
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
        /// Collider boxes in chunk cells, or `nil` when colliders are disabled.
        let boxes: [VoxelBox]?
    }

    private struct MeshingJob: Sendable {
        let coordinate: VoxelChunkCoordinate
        let grid: VoxelGrid
        let region: VoxelMeshingRegion
        let palette: VOXPalette
        let options: VoxelMeshingOptions
        let buildsColliders: Bool
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
            ),
            boxes: job.buildsColliders ? VoxelColliderBuilder.boxes(in: job.grid, region: job.region) : nil
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
        var moved: [(owner: Entity.ID, matrix: Transform3D)] = []
        worlds.forEach { entity, component in
            if component.storage.hasDirtyChunks {
                pending.append((entity.id, component))
            }
            // Physics reads local transforms, so colliders are placed in world space and follow the world when it moves.
            if component.generatesColliders, let built = component.storage.colliderOwnerMatrix {
                let current = Self.worldMatrix(of: entity)
                if current != built {
                    moved.append((entity.id, current))
                }
            }
        }

        for (ownerID, matrix) in moved {
            commands.queue.push { world in
                guard let owner = world.getEntityByID(ownerID), let component = owner.components[VoxelWorld3DComponent.self] else {
                    return
                }
                Self.moveColliders(of: component, to: matrix, in: world)
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
                    options: component.meshingOptions,
                    buildsColliders: component.generatesColliders
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

    /// The world matrix of a voxel world, composed from local transforms up the hierarchy.
    ///
    /// ``GlobalTransform`` is not used because it is stale until the first transform propagation after the world spawned.
    private static func worldMatrix(of entity: Entity) -> Transform3D {
        var matrix = entity.components[Transform.self]?.matrix ?? .identity
        var parentID = entity.components[RelationshipComponent.self]?.parent
        var visited: Set<Entity.ID> = [entity.id]
        while let id = parentID, visited.insert(id).inserted, let parent = entity.world?.getEntityByID(id) {
            matrix = (parent.components[Transform.self]?.matrix ?? .identity) * matrix
            parentID = parent.components[RelationshipComponent.self]?.parent
        }
        return matrix
    }

    private static func colliderTransform(chunkPosition: Vector3, ownerMatrix: Transform3D) -> Transform {
        let world = (ownerMatrix * Vector4(chunkPosition, 1)).xyz
        return Transform(rotation: Transform(matrix: ownerMatrix).rotation, scale: .one, position: world)
    }

    private static func chunkPosition(_ coordinate: VoxelChunkCoordinate, component: VoxelWorld3DComponent) -> Vector3 {
        let extent = Float(VoxelWorldStorage.chunkSize) * component.voxelSize
        return Vector3(Float(coordinate.x) * extent, Float(coordinate.y) * extent, Float(coordinate.z) * extent)
    }

    private static func moveColliders(of component: VoxelWorld3DComponent, to ownerMatrix: Transform3D, in world: World) {
        let storage = component.storage
        for (coordinate, id) in storage.colliderEntities {
            guard let entity = world.getEntityByID(id) else {
                continue
            }
            let transform = colliderTransform(chunkPosition: chunkPosition(coordinate, component: component), ownerMatrix: ownerMatrix)
            entity.components[Transform.self] = transform
            entity.components[PhysicsBody3DComponent.self]?.setTransform(position: transform.position, rotation: transform.rotation)
        }
        storage.colliderOwnerMatrix = ownerMatrix
    }

    private static func apply(_ chunks: [MeshedChunk], to owner: Entity, component: VoxelWorld3DComponent, in world: World) {
        let storage = component.storage
        let device = unsafe RenderEngine.shared.renderDevice
        let material = chunkMaterial()
        let chunkExtent = Float(VoxelWorldStorage.chunkSize) * component.voxelSize

        for chunk in chunks {
            let position = Vector3(
                Float(chunk.coordinate.x) * chunkExtent,
                Float(chunk.coordinate.y) * chunkExtent,
                Float(chunk.coordinate.z) * chunkExtent
            )
            if let boxes = chunk.boxes {
                applyCollider(boxes, chunk: chunk.coordinate, ownerMatrix: Self.worldMatrix(of: owner), to: owner, component: component, in: world)
            }

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

    /// Replaces the chunk's collider entity when its boxes changed, and removes it when the chunk has no solid voxels.
    ///
    /// Physics bodies are created once per entity, so a changed collider is a new entity; the old body is destroyed
    /// with its entity.
    private static func applyCollider(
        _ boxes: [VoxelBox],
        chunk: VoxelChunkCoordinate,
        ownerMatrix: Transform3D,
        to owner: Entity,
        component: VoxelWorld3DComponent,
        in world: World
    ) {
        let storage = component.storage
        if storage.colliderBoxes(for: chunk) == boxes, storage.colliderEntity(for: chunk) != nil || boxes.isEmpty {
            return
        }

        if let old = storage.colliderEntity(for: chunk) {
            world.removeEntity(old, recursively: true)
            storage.setColliderEntity(nil, for: chunk)
        }
        storage.setColliderBoxes(boxes, for: chunk)
        guard !boxes.isEmpty else {
            return
        }

        let entity = world.spawn("VoxelCollider \(chunk.x),\(chunk.y),\(chunk.z)")
        entity.components[Transform.self] = colliderTransform(chunkPosition: chunkPosition(chunk, component: component), ownerMatrix: ownerMatrix)
        storage.colliderOwnerMatrix = ownerMatrix
        entity.components[PhysicsBody3DComponent.self] = PhysicsBody3DComponent(
            shapes: VoxelColliderBuilder.shapes(for: boxes, voxelSize: component.voxelSize),
            material: component.colliderMaterial,
            mode: .static
        )
        owner.addChild(entity)
        storage.setColliderEntity(entity.id, for: chunk)
    }

    /// One diffuse material shared by all chunks; palette colors live in vertex colors.
    private static func chunkMaterial() -> PBRMaterial {
        let material = PBRMaterial()
        material.metallicFactor = 0
        material.roughnessFactor = 0.85
        return material
    }
}
