//
//  File.swift
//  
//
//  Created by v.prusakov on 3/21/23.
//

import Math

struct Mesh2DPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        scene.addSystem(ExctractMesh2DSystem.self)
    }
}

struct Mesh2DRenderPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        let drawPass = DrawMesh2dRenderPass()
        DrawPassStorage.setDrawPass(drawPass)
        
        scene.addSystem(Mesh2DRenderSystem.self)
    }
}

struct ExctractedMeshes2D: Component {
    var meshes: [ExctractedMesh2D] = []
}

struct ExctractedMesh2D: Component {
    let entityId: Entity.ID
    let mesh: Mesh2dComponent
    let transform: Transform
    let worldTransform: Transform3D
}

struct ExctractMesh2DSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(VisibilitySystem.self)]
    
    static let query = EntityQuery(where: .has(Mesh2dComponent.self) && .has(Transform.self) && .has(Visibility.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        let extractedEntity = EmptyEntity()
        var extractedMeshes = ExctractedMeshes2D()
        
        context.scene.performQuery(Self.query).forEach { entity in
            let (mesh, transform, visibility) = entity.components[Mesh2dComponent.self, Transform.self, Visibility.self]
            
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
        context.renderWorld.addEntity(extractedEntity)
    }
}

struct Mesh2DRenderSystem: System {
    
    static let query = EntityQuery(where: .has(Camera.self) && .has(VisibleEntities.self) && .has(RenderItems<Transparent2DRenderItem>.self))
    static let extractedMeshes = EntityQuery(where: .has(ExctractedMeshes2D.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        
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
    
    func draw(meshes: [ExctractedMesh2D], visibleEntities: VisibleEntities, items: inout [Transparent2DRenderItem], keys: Set<String>) {
        for mesh in meshes {
            guard visibleEntities.entityIds.contains(mesh.entityId) else {
                continue
            }
            
            let modelUnfirom = Mesh2dUniform(
                model: .identity,//mesh.worldTransform,
                modelTranspose: mesh.worldTransform.inverse
            )
            
            for model in mesh.mesh.mesh.models {
                for part in model.parts {
                    let material = mesh.mesh.materials[part.materialIndex]
                    
                    guard let pipeline = getOrCreatePipeline(for: part.vertexDescriptor, keys: keys, material: material) else {
                        print("No render pipeline for mesh")
                        continue
                    }
                    
                    let emptyEntity = EmptyEntity()
                    emptyEntity.components += ExctractedMeshPart2d(
                        part: part,
                        material: material,
                        modelUniform: modelUnfirom
                    )
                    
                    items.append(
                        Transparent2DRenderItem(
                            entity: emptyEntity,
                            batchEntity: emptyEntity,
                            drawPassId: DrawMesh2dRenderPass.identifier,
                            renderPipeline: pipeline,
                            sortKey: mesh.transform.position.z
                        )
                    )
                    
                }
            }
        }
    }
    
    func getOrCreatePipeline(for vertexDescriptor: VertexDescriptor, keys: Set<String>, material: Material) -> RenderPipeline? {
        let materialKey = material.getMesh2dMaterialKey(for: vertexDescriptor, keys: keys)
        
        if let data = MaterialStorage.shared.getMaterialData(for: material) as? Mesh2dMaterialStorageData {
            if let pipeline = data.pipelines[materialKey] {
                return pipeline
            }
            
            guard let (pipeline, shaderModule) = self.createPipeline(for: materialKey, material: material) else {
                return nil
            }
            
            data.shaderModule = shaderModule
            data.uniformBufferSet = data.makeUniformBufferSet(from: shaderModule)
            data.pipelines[materialKey] = pipeline
            
            return pipeline
        } else {
            guard let (pipeline, shaderModule) = self.createPipeline(for: materialKey, material: material) else {
                return nil
            }
            
            let data = Mesh2dMaterialStorageData()
            data.shaderModule = shaderModule
            data.uniformBufferSet = data.makeUniformBufferSet(from: shaderModule)
            data.pipelines[materialKey] = pipeline
            MaterialStorage.shared.setMaterialData(data, for: material)
            
            return pipeline
        }
    }
    
    private func createPipeline(for materialKey: MaterialMesh2dKey, material: Material) -> (RenderPipeline, ShaderModule)? {
        let compiler = ShaderCompiler(shaderSource: material.shaderSource)
        
        for define in materialKey.defines {
            compiler.setMacro(define.name, value: define.value, for: .vertex)
            compiler.setMacro(define.name, value: define.value, for: .fragment)
        }
        
        do {
            let shaderModule = try compiler.compileShaderModule()
            
            guard let pipelineDesc = material.configureRenderPipeline(for: materialKey.vertexDescritor, keys: materialKey.keys, shaderModule: shaderModule) else {
                return nil
            }
            
            return (RenderEngine.shared.makeRenderPipeline(from: pipelineDesc), shaderModule)
        } catch {
            print("[Mesh2DRenderSystem]", error.localizedDescription)
            return nil
        }
    }
}

struct ExctractedMeshPart2d: Component {
    let part: Mesh.Part
    let material: Material
    let modelUniform: Mesh2dUniform
}

struct MaterialMesh2dKey: Hashable {
    let defines: [ShaderDefine]
    let keys: Set<String>
    let vertexDescritor: VertexDescriptor
}

class Mesh2dMaterialStorageData: MaterialStorageData {
    var pipelines: [MaterialMesh2dKey : RenderPipeline] = [:]
}

public struct Mesh2dComponent: Component {
    public var mesh: Mesh
    public var materials: [Material]
    
    public init(mesh: Mesh, materials: [Material]) {
        self.mesh = mesh
        self.materials = materials
    }
}

struct Mesh2dUniform {
    let model: Transform3D
    let modelTranspose: Transform3D
}

struct DrawMesh2dRenderPass: DrawPass {
    
    let meshUniformBufferSet: UniformBufferSet
    
    init() {
        self.meshUniformBufferSet = RenderEngine.shared.makeUniformBufferSet()
        self.meshUniformBufferSet.initBuffers(for: Mesh2dUniform.self, binding: 2, set: 0)
    }
    
    func render(in context: Context, item: Transparent2DRenderItem) throws {
        let meshComponent = item.entity.components[ExctractedMeshPart2d.self]!

        let part = meshComponent.part
        let drawList = context.drawList
        
        guard let materialData = MaterialStorage.shared.getMaterialData(for: meshComponent.material) else {
            return
        }
        
        guard let reflectionData = materialData.shaderModule?.reflectionData else {
            return
        }
        
        guard let cameraViewUniform = context.view.components[GlobalViewUniformBufferSet.self] else {
            return
        }
        
        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(binding: BufferIndex.baseUniform, set: 0, frameIndex: context.device.currentFrameIndex)
        context.drawList.appendUniformBuffer(uniformBuffer)
        
        drawList.pushDebugName("Mesh 2d Render")
        
        for buffer in reflectionData.shaderBuffers.values {
            guard let uniformBuffer = materialData.uniformBufferSet?.getBuffer(binding: buffer.binding, set: 0, frameIndex: RenderEngine.shared.currentFrameIndex) else {
                continue
            }

            if buffer.shaderStage.contains(.vertex) {
                drawList.appendUniformBuffer(uniformBuffer, for: .vertex)
            }

            if buffer.shaderStage.contains(.fragment) {
                drawList.appendUniformBuffer(uniformBuffer, for: .fragment)
            }
        }
        
        let meshUniformBuffer = self.meshUniformBufferSet.getBuffer(binding: 2, set: 0, frameIndex: RenderEngine.shared.currentFrameIndex)
        meshUniformBuffer.setData(meshComponent.modelUniform)
        drawList.appendUniformBuffer(meshUniformBuffer)
        
        drawList.appendVertexBuffer(part.vertexBuffer)
        drawList.bindIndexBuffer(part.indexBuffer)
        drawList.bindIndexPrimitive(part.primitiveTopology.indexPrimitive)
        drawList.bindRenderPipeline(item.renderPipeline)
        
        drawList.drawIndexed(indexCount: part.indexCount, instancesCount: 1)
        drawList.popDebugName()
    }
}

extension Mesh.PrimitiveTopology {
    var indexPrimitive: IndexPrimitive {
        switch self {
        case .points:
            return .points
        case .triangleList:
            return .triangle
        case .triangleStrip:
            return .triangleStrip
        case .lineList:
            return .line
        case .lineStrip:
            return .lineStrip
        }
    }
}

extension Material {
    func getMesh2dMaterialKey(for vertexDescritor: VertexDescriptor, keys: Set<String>) -> MaterialMesh2dKey {
        let defines = self.collectDefines(for: vertexDescritor, keys: keys)
        return MaterialMesh2dKey(defines: defines, keys: keys, vertexDescritor: vertexDescritor)
    }
}
