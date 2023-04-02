//
//  Mesh2DPlugin.swift
//  
//
//  Created by v.prusakov on 3/21/23.
//

import Math

// MARK: - Mesh 2D Plugin -

struct Mesh2DPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        scene.addSystem(ExctractMesh2DSystem.self)
    }
}

struct ExctractedMeshes2D: Component {
    var meshes: [ExctractedMesh2D] = []
}

struct ExctractedMesh2D: Component {
    let entityId: Entity.ID
    let mesh: Mesh2DComponent
    let transform: Transform
    let worldTransform: Transform3D
}

struct ExctractMesh2DSystem: System {
    
    static var dependencies: [SystemDependency] = [.after(VisibilitySystem.self)]
    
    static let query = EntityQuery(where: .has(Mesh2DComponent.self) && .has(Transform.self) && .has(Visibility.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
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
        context.renderWorld.addEntity(extractedEntity)
    }
}

// MARK: - Mesh 2D Render Plugin -

struct Mesh2DRenderPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        let drawPass = Mesh2DDrawPass()
        DrawPassStorage.setDrawPass(drawPass)
        
        scene.addSystem(Mesh2DRenderSystem.self)
    }
}

struct Mesh2DRenderSystem: System {
    
    static let query = EntityQuery(where: .has(Camera.self) && .has(VisibleEntities.self) && .has(RenderItems<Transparent2DRenderItem>.self))
    
    static let extractedMeshes = EntityQuery(where: .has(ExctractedMeshes2D.self))
    
    let meshDrawPassIdentifier = Mesh2DDrawPass.identifier
    
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
            
            let modelUniform = Mesh2DUniform(
                model: mesh.worldTransform,
                modelInverseTranspose: mesh.worldTransform.inverse.transpose
            )
            
            for model in mesh.mesh.mesh.models {
                for part in model.parts {
                    let material = mesh.mesh.materials[part.materialIndex]
                    
                    guard let pipeline = getOrCreatePipeline(for: part.vertexDescriptor, keys: keys, material: material) else {
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
    
    func getOrCreatePipeline(for vertexDescriptor: VertexDescriptor, keys: Set<String>, material: Material) -> RenderPipeline? {
        let materialKey = material.getMesh2dMaterialKey(for: vertexDescriptor, keys: keys)
        
        if let data = MaterialStorage.shared.getMaterialData(for: material) as? Mesh2dMaterialStorageData {
            if let pipeline = data.pipelines[materialKey] {
                return pipeline
            }
            
            guard let (pipeline, shaderModule) = self.createPipeline(for: materialKey, material: material) else {
                return nil
            }
            
            data.updateUniformBuffers(from: shaderModule)
            data.pipelines[materialKey] = pipeline
            
            material.update()
            
            return pipeline
        } else {
            guard let (pipeline, shaderModule) = self.createPipeline(for: materialKey, material: material) else {
                return nil
            }
            
            let data = Mesh2dMaterialStorageData()
            data.updateUniformBuffers(from: shaderModule)
            data.pipelines[materialKey] = pipeline
            MaterialStorage.shared.setMaterialData(data, for: material)
            
            material.update()
            
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
            assertionFailure("[Mesh2DRenderSystem] \(error.localizedDescription)")
            return nil
        }
    }
}

struct ExctractedMeshPart2d: Component {
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

extension Material {
    func getMesh2dMaterialKey(for vertexDescritor: VertexDescriptor, keys: Set<String>) -> MaterialMesh2dKey {
        let defines = self.collectDefines(for: vertexDescritor, keys: keys)
        return MaterialMesh2dKey(defines: defines, keys: keys, vertexDescritor: vertexDescritor)
    }
}
