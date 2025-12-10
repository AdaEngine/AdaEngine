//
//  Mesh2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/21/23.
//

import AdaApp
import AdaECS
import AdaTransform
import AdaUtils
@_spi(Internal) import AdaRender
import Math

// MARK: - Mesh 2D Plugin -

/// Plugin to exctract meshes to RenderWorld.
public struct Mesh2DPlugin: Plugin {

    /// Initialize a new mesh 2D plugin.
    public init() {}

    /// Setup the plugin.
    ///
    /// - Parameter app: The app.
    public func setup(in app: AppWorlds) {
        Mesh2DComponent.registerComponent()

        app.main.registerRequiredComponent(Visibility.self, for: Mesh2DComponent.self)
        app.main.registerRequiredComponent(BoundingComponent.self, for: Mesh2DComponent.self)

        let renderWorld = app.getSubworldBuilder(by: .renderWorld)
            .unwrap(message: "RenderWorld not found")
        renderWorld
            .insertResource(ExctractedMeshes2D())
            .insertResource(Mesh2DDrawPass())
            .addSystem(ExctractMesh2DSystem.self, on: .extract)
            .addSystem(Mesh2DRenderSystem.self, on: .update)
    }
}

/// A resource that contains extracted meshes.
public struct ExctractedMeshes2D: Resource {
    /// The meshes.
    public var meshes: [ExctractedMesh2D] = []

    /// Initialize a new extracted meshes.
    ///
    /// - Parameter meshes: The meshes.
    public init(meshes: [ExctractedMesh2D] = []) {
        self.meshes = meshes
    }
}

/// A component that contains an extracted mesh.
@Component
public struct ExctractedMesh2D: Sendable {
    /// The entity id.
    public var entityId: Entity.ID
    /// The mesh.
    public var mesh: Mesh2DComponent
    /// The transform.
    public var transform: Transform
    /// The world transform.
    public var worldTransform: Transform3D

    public init(entityId: Entity.ID, mesh: Mesh2DComponent, transform: Transform, worldTransform: Transform3D) {
        self.entityId = entityId
        self.mesh = mesh
        self.transform = transform
        self.worldTransform = worldTransform
    }
}

/// System to render exctract meshes to RenderWorld.
@PlainSystem
public struct ExctractMesh2DSystem {
    @Extract<
        Query<Entity, Mesh2DComponent, Transform, GlobalTransform, Visibility>
    >
    private var query

    @ResMut<ExctractedMeshes2D>
    private var extractedMeshes

    public init(world: World) { }

    public func update(context: UpdateContext) {
        extractedMeshes.meshes.removeAll(keepingCapacity: true)
        self.query.wrappedValue.forEach { entity, mesh, transform, globalTransform, visibility in
            if visibility == .hidden {
                return
            }

            extractedMeshes.meshes.append(
                ExctractedMesh2D(
                    entityId: entity.id,
                    mesh: mesh,
                    transform: transform,
                    worldTransform: globalTransform.matrix
                )
            )
        }
    }
}

// MARK: - Mesh 2D Render Plugin -

/// System in RenderWorld for rendering 2D meshes.
@PlainSystem
public struct Mesh2DRenderSystem: Sendable {

    @FilterQuery<
        VisibleEntities, 
        Ref<RenderItems<Transparent2DRenderItem>>,
        With<Camera>
    >
    private var query

    @Res<ExctractedMeshes2D>
    private var extractedMeshes

    @Res<Mesh2DDrawPass>
    private var meshDrawPass

    @Res<RenderDeviceHandler>
    private var renderDevice

    @Commands
    private var commands

    public init(world: World) { }

    public func update(context: UpdateContext) {
        self.query.forEach { visibleEntities, renderItems in
            self.draw(
                visibleEntities: visibleEntities,
                items: renderItems,
                keys: []
            )
        }
    }

    func draw(
        visibleEntities: VisibleEntities,
        items: Ref<RenderItems<Transparent2DRenderItem>>,
        keys: Set<String>
    ) {
        for mesh in extractedMeshes.meshes {
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

                    guard let pipeline = material.getOrCreatePipeline(
                        for: part.vertexDescriptor,
                        keys: keys,
                        device: renderDevice.renderDevice
                    ) else {
                        assertionFailure("No render pipeline for mesh")
                        continue
                    }

                    let entity = commands.spawn() {
                        ExctractedMeshPart2d(
                            part: part,
                            material: material,
                            modelUniform: modelUniform
                        )
                    }.entityId

                    items.items.append(
                        Transparent2DRenderItem(
                            entity: entity,
                            batchEntity: entity,
                            drawPass: self.meshDrawPass,
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

public class Mesh2dMaterialStorageData: MaterialStorageData {
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
    func getOrCreatePipeline(
        for vertexDescriptor: VertexDescriptor,
        keys: Set<String>,
        device: RenderDevice
    ) -> RenderPipeline? {
        let materialKey = self.getMesh2dMaterialKey(for: vertexDescriptor, keys: keys)

        if let data = unsafe MaterialStorage.shared.getMaterialData(for: self) as? Mesh2dMaterialStorageData {
            if let pipeline = data.pipelines[materialKey] {
                return pipeline
            }

            guard let (pipeline, shaderModule) = self.createPipeline(for: materialKey, device: device) else {
                return nil
            }

            data.updateUniformBuffers(from: shaderModule)
            data.pipelines[materialKey] = pipeline

            self.update()

            return pipeline
        } else {
            guard let (pipeline, shaderModule) = self.createPipeline(for: materialKey, device: device) else {
                return nil
            }

            let data = Mesh2dMaterialStorageData()
            data.updateUniformBuffers(from: shaderModule)
            data.pipelines[materialKey] = pipeline
            unsafe MaterialStorage.shared.setMaterialData(data, for: self)

            self.update()

            return pipeline
        }
    }

    private func createPipeline(
        for materialKey: MaterialMesh2dKey,
        device: RenderDevice
    ) -> (RenderPipeline, ShaderModule)? {
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

            return (device.createRenderPipeline(from: pipelineDesc), shaderModule)
        } catch {
            assertionFailure("[Mesh2DRenderSystem] \(error)")
            return nil
        }
    }
}
