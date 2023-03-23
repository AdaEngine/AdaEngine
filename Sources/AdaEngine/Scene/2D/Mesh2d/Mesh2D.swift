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
                    items: &renderItems.items
                )
            }
            
            entity.components += renderItems
        }
    }
    
    func draw(meshes: [ExctractedMesh2D], visibleEntities: VisibleEntities, items: inout [Transparent2DRenderItem]) {
        for mesh in meshes {
            guard visibleEntities.entityIds.contains(mesh.entityId) else {
                continue
            }
            
            let emptyEntity = EmptyEntity()
            emptyEntity.components += mesh.mesh
//
//            items.append(
//                Transparent2DRenderItem(
//                    entity: emptyEntity,
//                    batchEntity: emptyEntity,
//                    drawPassId: DrawMesh2dRenderPass.identifier,
//                    renderPipeline: <#T##RenderPipeline#>,
//                    sortKey: mesh.transform.position.z
//                )
//            )
        }
    }
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
    let viewTransform: Transform3D
}

struct DrawMesh2dRenderPass: DrawPass {
    func render(in context: Context, item: Transparent2DRenderItem) throws {
        
        let meshComponent = item.entity.components[Mesh2dComponent.self]!
        let mesh = meshComponent.mesh
        
        let drawList = context.drawList
        
        for model in mesh.models {
            for part in model.parts {
                let material = meshComponent.materials[part.materialIndex]
                
                for buffer in material.shaderModule.reflectionData.shaderBuffers.values {
                    let uniformBuffer = material.uniformBufferSet.getBuffer(binding: buffer.binding, set: 0, frameIndex: RenderEngine.shared.currentFrameIndex)
                    
                    if buffer.shaderStage.contains(.vertex) {
                        drawList.appendUniformBuffer(uniformBuffer, for: .vertex)
                    }
                    
                    if buffer.shaderStage.contains(.fragment) {
                        drawList.appendUniformBuffer(uniformBuffer, for: .fragment)
                    }
                }

                drawList.appendVertexBuffer(part.vertexBuffer)
                drawList.bindIndexBuffer(part.indexBuffer)
                drawList.bindIndexPrimitive(part.primitiveTopology.indexPrimitive)
                drawList.bindRenderPipeline(item.renderPipeline)
                
                drawList.drawIndexed(indexCount: part.indexCount, instancesCount: 1)
            }
        }
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
