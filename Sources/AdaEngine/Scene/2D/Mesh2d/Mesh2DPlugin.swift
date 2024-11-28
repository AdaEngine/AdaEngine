//
//  Mesh2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/21/23.
//

import Math

// MARK: - Mesh 2D Plugin -

/// Plugin to exctract meshes to RenderWorld
struct Mesh2DPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        scene.addSystem(ExctractMesh2DSystem.self)
    }
}

@Component
public struct ExctractedMeshes2D {
    public var meshes: [ExctractedMesh2D] = []

    public init(meshes: [ExctractedMesh2D] = []) {
        self.meshes = meshes
    }
}

@Component
public struct ExctractedMesh2D {
    public var entityId: Entity.ID
    public var mesh: Mesh2DComponent
    public var transform: Transform
    public var worldTransform: Transform3D

    public init(entityId: Entity.ID, mesh: Mesh2DComponent, transform: Transform, worldTransform: Transform3D) {
        self.entityId = entityId
        self.mesh = mesh
        self.transform = transform
        self.worldTransform = worldTransform
    }
}

/// System to render exctract meshes to RenderWorld.
public struct ExctractMesh2DSystem: System {

    public static var dependencies: [SystemDependency] = [.after(VisibilitySystem.self)]

    static let query = EntityQuery(where: .has(Mesh2DComponent.self) && .has(Transform.self) && .has(Visibility.self))

    public init(scene: Scene) { }

    public func update(context: UpdateContext) {
        let extractedEntity = EmptyEntity()
        var extractedMeshes = ExctractedMeshes2D()

        context.scene.performQuery(Self.query).forEach { entity in
            let (mesh, transform, visibility) = entity.components[Mesh2DComponent.self, Transform.self, Visibility.self]

            if !visibility.isVisible {
                return
            }

            let worldTransform = context.scene.worldTransformMatrix(for: entity)

            extractedMeshes.meshes.append(
                ExctractedMesh2D(
                    entityId: entity.id,
                    mesh: mesh,
                    transform: transform,
                    worldTransform: worldTransform
                )
            )
        }

        extractedEntity.components += extractedMeshes
        Task {
            await Application.shared.renderWorld.addEntity(extractedEntity)
        }
    }
}

// MARK: - Mesh 2D Render Plugin -

/// Plugin for RenderWorld for rendering 2D meshes.
struct Mesh2DRenderPlugin: RenderWorldPlugin {
    func setup(in world: RenderWorld) {
        let drawPass = Mesh2DDrawPass()
        DrawPassStorage.setDrawPass(drawPass)

        world.addSystem(Mesh2DRenderSystem.self)
    }
}

/// System in RenderWorld for rendering 2D meshes.
public struct Mesh2DRenderSystem: RenderSystem {

    static let query = EntityQuery(where: .has(Camera.self) && .has(VisibleEntities.self) && .has(RenderItems<Transparent2DRenderItem>.self))

    static let extractedMeshes = EntityQuery(where: .has(ExctractedMeshes2D.self))

    let meshDrawPassIdentifier = Mesh2DDrawPass.identifier

    public init(scene: Scene) { }

    public func update(context: UpdateContext) {
        let exctractedMeshes = context.scene.performQuery(Self.extractedMeshes)

        context.scene.performQuery(Self.query).forEach { entity in
            var (visibleEntities, renderItems) = entity.components[VisibleEntities.self, RenderItems<Transparent2DRenderItem>.self]

            for exctractedMesh in exctractedMeshes {
                let meshes = exctractedMesh.components[ExctractedMeshes2D.self]!.meshes
                self.draw(
                    meshes: meshes,
                    visibleEntities: visibleEntities,
                    items: &renderItems.items,
                    keys: []
                )
            }

            entity.components += renderItems
        }
    }

    @MainActor func draw(meshes: [ExctractedMesh2D], visibleEntities: VisibleEntities, items: inout [Transparent2DRenderItem], keys: Set<String>) {
        for mesh in meshes {
            guard visibleEntities.entityIds.contains(mesh.entityId) else {
                continue
            }

            let modelUniform = Mesh2DUniform(
                model: mesh.worldTransform,
                modelInverseTranspose: mesh.worldTransform.inverse.transpose
            )

            for model in mesh.mesh.mesh.models {
                for part in model.parts {
                    let material = mesh.mesh.materials[part.materialIndex]

                    guard let pipeline = material.getOrCreatePipeline(for: part.vertexDescriptor, keys: keys) else {
                        assertionFailure("No render pipeline for mesh")
                        continue
                    }

                    let emptyEntity = EmptyEntity()
                    emptyEntity.components += ExctractedMeshPart2d(
                        part: part,
                        material: material,
                        modelUniform: modelUniform
                    )

                    items.append(
                        Transparent2DRenderItem(
                            entity: emptyEntity,
                            batchEntity: emptyEntity,
                            drawPassId: self.meshDrawPassIdentifier,
                            renderPipeline: pipeline,
                            sortKey: mesh.transform.position.z
                        )
                    )
                }
            }
        }
    }
}

@Component
struct ExctractedMeshPart2d {
    let part: Mesh.Part
    let material: Material
    let modelUniform: Mesh2DUniform
}

struct MaterialMesh2dKey: Hashable {
    let defines: [ShaderDefine]
    let keys: Set<String>
    let vertexDescritor: VertexDescriptor
}

class Mesh2dMaterialStorageData: MaterialStorageData {
    var pipelines: [MaterialMesh2dKey : RenderPipeline] = [:]
}

// TODO: Think about it, maybe we should move it to other dir.
extension Material {

    /// Get Mesh2D material key which has been used for caching.
    func getMesh2dMaterialKey(for vertexDescritor: VertexDescriptor, keys: Set<String>) -> MaterialMesh2dKey {
        let defines = self.collectDefines(for: vertexDescritor, keys: keys)
        return MaterialMesh2dKey(defines: defines, keys: keys, vertexDescritor: vertexDescritor)
    }

    /// Get or create Mesh2D Material render pipeline from vertex and keys.
    func getOrCreatePipeline(for vertexDescriptor: VertexDescriptor, keys: Set<String>) -> RenderPipeline? {
        let materialKey = self.getMesh2dMaterialKey(for: vertexDescriptor, keys: keys)

        if let data = MaterialStorage.shared.getMaterialData(for: self) as? Mesh2dMaterialStorageData {
            if let pipeline = data.pipelines[materialKey] {
                return pipeline
            }

            guard let (pipeline, shaderModule) = self.createPipeline(for: materialKey) else {
                return nil
            }

            data.updateUniformBuffers(from: shaderModule)
            data.pipelines[materialKey] = pipeline

            self.update()

            return pipeline
        } else {
            guard let (pipeline, shaderModule) = self.createPipeline(for: materialKey) else {
                return nil
            }

            let data = Mesh2dMaterialStorageData()
            data.updateUniformBuffers(from: shaderModule)
            data.pipelines[materialKey] = pipeline
            MaterialStorage.shared.setMaterialData(data, for: self)

            self.update()

            return pipeline
        }
    }

    private func createPipeline(for materialKey: MaterialMesh2dKey) -> (RenderPipeline, ShaderModule)? {
        let compiler = ShaderCompiler(shaderSource: self.shaderSource)

        for define in materialKey.defines {
            compiler.setMacro(define.name, value: define.value, for: .vertex)
            compiler.setMacro(define.name, value: define.value, for: .fragment)
        }

        do {
            let shaderModule = try compiler.compileShaderModule()

            guard let pipelineDesc = self.configureRenderPipeline(for: materialKey.vertexDescritor, keys: materialKey.keys, shaderModule: shaderModule) else {
                return nil
            }

            return (RenderEngine.shared.renderDevice.createRenderPipeline(from: pipelineDesc), shaderModule)
        } catch {
            assertionFailure("[Mesh2DRenderSystem] \(error.localizedDescription)")
            return nil
        }
    }
}
