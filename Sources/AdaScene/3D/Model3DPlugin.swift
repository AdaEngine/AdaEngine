//
//  Model3DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import AdaApp
import AdaECS
import AdaCorePipelines
@_spi(Internal) import AdaRender
import AdaTransform
import Math

/// Plugin for extracting 3D models from scene to RenderWorld.
public struct Model3DPlugin: Plugin {

    public init() {}
    
    public func setup(in app: AppWorlds) {
        Mesh3DComponent.registerComponent()
        
        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }
        
        renderWorld
            .insertResource(RenderItems<Opaque3DRenderItem>())
            .insertResource(Opaque3DInstanceBuffers())
            .insertResource(RenderPipelines(configurator: Flat3DPipeline()))
            .insertResource(Model3DDrawPass())
            .addSystem(ExtractModel3DSystem.self, on: .extract)
    }
}

@System
func ExtractModel3D(
    _ query: Extract<Query<Entity, Mesh3DComponent, GlobalTransform>>,
    _ renderItems: ResMut<RenderItems<Opaque3DRenderItem>>,
    _ instanceBuffers: ResMut<Opaque3DInstanceBuffers>,
    _ renderDevice: Res<RenderDeviceHandler>,
    _ drawPass: Res<Model3DDrawPass>
) {
    var items = renderItems.items
    items.removeAll(keepingCapacity: true)
    var instances = instanceBuffers.wrappedValue
    instances.beginFrame()
    var currentBatchKey: Opaque3DBatchKey?
    var currentBatchIndex: Int?

    query.wrappedValue.forEach { entity, mesh3d, transform in
        let mesh = mesh3d.mesh
        for (modelIndex, model) in mesh.models.enumerated() {
            for (partIndex, part) in model.parts.enumerated() {
                let material = mesh3d.materials[part.materialIndex]
                let pbrMaterial = material as? PBRMaterial
                let instanceIndex = instances.append(
                    Flat3DInstanceData(
                        modelMatrix: transform.matrix,
                        color: pbrMaterial?.baseColorFactor ?? .one,
                        material: Vector4(
                            pbrMaterial?.roughnessFactor ?? 1,
                            pbrMaterial?.metallicFactor ?? 0,
                            0,
                            0
                        )
                    )
                )
                let key = Opaque3DBatchKey(part: part, material: material)

                if key == currentBatchKey, let currentBatchIndex {
                    let lowerBound = items[currentBatchIndex].batchRange?.lowerBound ?? instanceIndex
                    items[currentBatchIndex].batchRange = lowerBound..<(instanceIndex + 1)
                    continue
                }

                currentBatchKey = key
                currentBatchIndex = items.count
                items.append(
                    Opaque3DRenderItem(
                        entity: entity.id,
                        drawPass: drawPass.wrappedValue,
                        sortKey: 0,
                        modelIndex: modelIndex,
                        partIndex: partIndex,
                        mesh: mesh,
                        material: material,
                        worldTransform: transform.matrix,
                        batchRange: instanceIndex..<(instanceIndex + 1)
                    )
                )
            }
        }
    }

    instances.write(to: renderDevice.renderDevice)
    instanceBuffers.wrappedValue = instances
    renderItems.items = items
}

public final class Model3DDrawPass: DrawPass, @unchecked Sendable {
    public init() {}
    
    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: Opaque3DRenderItem
    ) throws {
        let part = item.mesh.models[item.modelIndex].parts[item.partIndex]
        let renderDevice = world.getResource(RenderDeviceHandler.self)?.renderDevice
        guard let renderDevice else {
            return
        }

        let pipelines = world.getRefResource(RenderPipelines<Flat3DPipeline>.self)
        let pipeline = pipelines.wrappedValue.pipeline(for: part.vertexDescriptor, device: renderDevice)
        guard
            let batchRange = item.batchRange,
            let instances = world.getResource(Opaque3DInstanceBuffers.self)?.currentBuffer
        else {
            return
        }

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setVertexBuffer(part.vertexBuffer, offset: 0, slot: 0)
        renderEncoder.setVertexBuffer(
            instances,
            offset: Int(batchRange.lowerBound) * MemoryLayout<Flat3DInstanceData>.stride,
            slot: 3
        )
        renderEncoder.setIndexBuffer(part.indexBuffer, offset: 0)
        renderEncoder.drawIndexed(
            indexCount: part.indexCount,
            indexBufferOffset: 0,
            instanceCount: Int(batchRange.count)
        )
    }
}

private struct Opaque3DBatchKey: Equatable {
    let vertexBuffer: ObjectIdentifier
    let indexBuffer: ObjectIdentifier
    let material: ObjectIdentifier

    init(part: Mesh.Part, material: Material) {
        self.vertexBuffer = ObjectIdentifier(part.vertexBuffer)
        self.indexBuffer = ObjectIdentifier(part.indexBuffer)
        self.material = ObjectIdentifier(material)
    }
}

struct Opaque3DInstanceBuffers: Resource {
    private var buffers: [(any Buffer)?]
    private var instances: [Flat3DInstanceData]
    private var currentIndex: Int

    init() {
        let bufferCount = max(1, unsafe RenderEngine.configurations.maxFramesInFlight)
        self.buffers = Array(repeating: nil, count: bufferCount)
        self.instances = []
        self.currentIndex = bufferCount - 1
    }

    var currentBuffer: BufferData<Flat3DInstanceData>? {
        guard let buffer = buffers[currentIndex] else {
            return nil
        }

        var data = BufferData<Flat3DInstanceData>(elements: [])
        data.buffer = buffer
        return data
    }

    mutating func beginFrame() {
        currentIndex = (currentIndex + 1) % buffers.count
        instances.removeAll(keepingCapacity: true)
    }

    mutating func append(_ instance: Flat3DInstanceData) -> Int32 {
        let index = Int32(instances.count)
        instances.append(instance)
        return index
    }

    mutating func write(to renderDevice: RenderDevice) {
        guard !instances.isEmpty else {
            return
        }

        let requiredLength = instances.count * MemoryLayout<Flat3DInstanceData>.stride
        if buffers[currentIndex]?.length ?? 0 < requiredLength {
            buffers[currentIndex] = renderDevice.createBuffer(
                label: "Opaque 3D Instances \(currentIndex)",
                length: requiredLength,
                options: .storageShared
            )
        }
        buffers[currentIndex]?.setElements(&instances)
    }
}
