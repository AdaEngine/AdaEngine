//
//  Scene2DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

import AdaApp
import AdaECS
import AdaUtils
import Math

/// Plugin for RenderWorld added 2D render capatibilites.
public struct Scene2DPlugin: Plugin {

    /// Render graph name.
    public static let renderGraph = "render_graph_2d"
    
    public init() {}
    
    /// Input slots of render graph.
    public enum InputNode {
        public static let view = "view"
    }

    public func setup(in app: AppWorlds) {
        guard let app = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        // Add Systems
        app.addSystem(BatchTransparent2DItemsSystem.self)

        Task { @RenderGraphActor in
            var graph = RenderGraph(label: "Scene 2D Render Graph")
            let entryNode = graph.addEntryNode(inputs: [
                RenderSlot(name: InputNode.view, kind: .entity)
            ])

            graph.addNode(Main2DRenderNode())
            graph.addNode(PresentNode())
            
            graph.addSlotEdge(
                fromNode: entryNode,
                outputSlot: InputNode.view,
                toNode: Main2DRenderNode.name,
                inputSlot: Main2DRenderNode.InputNode.view
            )
            graph.addNodeEdge(from: Main2DRenderNode.name, to: PresentNode.name)

            await app
                .getRefResource(RenderGraph.self)
                .wrappedValue
                .addSubgraph(graph, name: Self.renderGraph)
        }
    }
}

/// This render node responsible for rendering ``Transparent2DRenderItem``.
public struct Main2DRenderNode: RenderNode {
    
    /// Input slots of render node.
    public enum InputNode {
        public static let view = "view"
    }

    @Query<
        Entity,
        Camera,
        RenderItems<Transparent2DRenderItem>,
        RenderViewTarget
    >
    private var query

    public init() {}
    
    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]

    public func update(from world: World) {
        query.update(from: world)
    }

    public func execute(context: inout Context, renderContext: RenderContext) async throws -> [RenderSlotValue] {
        guard let view = context.viewEntity else {
            return []
        }

        try query.forEach { entity, camera, renderItems, target in
            if entity != view {
                return
            }
            
            let sortedRenderItems = renderItems.sorted()
            let clearColor = camera.clearFlags.contains(.solid) ? camera.backgroundColor : .surfaceClearColor
            let commandBuffer = renderContext.commandQueue.makeCommandBuffer()

            guard
                let texture = target.mainTexture
            else {
                return
            }

            let renderPass = commandBuffer.beginRenderPass(
                RenderPassDescriptor(
                    label: "Main 2d Render Pass",
                    colorAttachments: [
                        .init(
                            texture: texture,
                            operation: OperationDescriptor(
                                loadAction: .dontCare,
                                storeAction: .dontCare
                            ),
                            clearColor: clearColor
                        )
                    ],
                    depthStencilAttachment: nil
                )
            )

            if let viewport = camera.viewport {
                renderPass.setViewport(viewport.rect)
            }

            if !sortedRenderItems.items.isEmpty {
                try sortedRenderItems.render(with: renderPass, world: context.world, view: view)
            }

            renderPass.endRenderPass()
            commandBuffer.commit()
        }

        return []
    }
}

/// This node is responsible for presenting the result to the screen.
public struct PresentNode: RenderNode {
    
    public enum InputNode {
        public static let view = "view"
    }
    
    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]
    
    public init() {}
    
    public func execute(context: inout Context, renderContext: RenderContext) async throws -> [RenderSlotValue] {
        guard
            let viewEntity = context.viewEntity,
            let target = viewEntity.components[RenderViewTarget.self]
        else {
            return []
        }

        guard let upsalePipeline = context.world.getResource(UpscalePipeline.self) else {
            return []
        }

        if let mainTexture = target.mainTexture,
           let outputTexture = target.outputTexture,
           mainTexture !== outputTexture {

            //            if mainTexture.size != outputTexture.size {
            //                await UpscalePass.shared.render(
            //                    context: renderContext,
            //                    mainTexture: mainTexture,
            //                    outputTexture: outputTexture
            //                )
            //            } else {
            let commandBuffer = renderContext.commandQueue.makeCommandBuffer()
            let renderPass = commandBuffer.beginRenderPass(
                RenderPassDescriptor(
                    label: "Upscale Pass",
                    colorAttachments: [
                        .init(
                            texture: outputTexture,
                            operation: OperationDescriptor(
                                loadAction: .dontCare,
                                storeAction: .store
                            )
                        )
                    ],
                    depthStencilAttachment: nil
                )
            )

            renderPass.setFragmentTexture(mainTexture, index: 0)
            renderPass.setFragmentSamplerState(mainTexture.sampler, index: 0)
            renderPass.setRenderPipelineState(upsalePipeline.renderPipeline)
            
            renderPass.draw(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            renderPass.endRenderPass()
            commandBuffer.commit()



//            let blitEncoder = commandBuffer.beginBlitPass(BlitPassDescriptor(label: "Present Blit"))
//
//            blitEncoder.copyTextureToTexture(
//                source: mainTexture,
//                sourceOrigin: Origin3D(),
//                sourceSize: Size3D(width: mainTexture.width, height: mainTexture.height, depth: 1),
//                sourceMipLevel: 0,
//                sourceSlice: 0,
//                destination: outputTexture,
//                destinationOrigin: Origin3D(),
//                destinationMipLevel: 0,
//                destinationSlice: 0
//            )
//
//            blitEncoder.endBlitPass()
//            commandBuffer.commit()
            //            }
        }

        return []
    }
}

class UpscalePass {
    private var pipeline: RenderPipeline?
    private var quadMesh: Mesh?
    private var sampler: Sampler?

    func render(
        context: RenderContext,
        mainTexture: Texture,
        outputTexture: Texture
    ) {
        let device = unsafe RenderEngine.shared.renderDevice

        if quadMesh == nil {
            quadMesh = createQuadMesh()
        }

        if sampler == nil {
            var descriptor = SamplerDescriptor()
            descriptor.magFilter = .linear
            descriptor.minFilter = .linear
            sampler = device.createSampler(from: descriptor)
        }

        // Try to get pixel format from RenderTexture, otherwise default to bgra8
        let pixelFormat = (outputTexture as? RenderTexture)?.pixelFormat ?? .bgra8

        if pipeline == nil || pipeline?.descriptor.colorAttachments[0].format != pixelFormat {
            pipeline = try? createPipeline(device: device, pixelFormat: pixelFormat)
        }

        guard let pipeline = pipeline, let quadMesh = quadMesh, let sampler = sampler else { return }

        let commandBuffer = context.commandQueue.makeCommandBuffer()
        let renderPass = commandBuffer.beginRenderPass(
            RenderPassDescriptor(
                label: "Upscale Pass",
                colorAttachments: [
                    .init(
                        texture: outputTexture,
                        operation: OperationDescriptor(
                            loadAction: .dontCare,
                            storeAction: .store
                        )
                    )
                ]
            )
        )

        renderPass.setRenderPipelineState(pipeline)
        renderPass.setFragmentTexture(mainTexture, index: 0)
        renderPass.setFragmentSamplerState(sampler, index: 0)

        let part = quadMesh.models[0].parts[0]

        var bufferData = BufferData<UInt8>(elements: [])
        bufferData.buffer = part.vertexBuffer
        renderPass.setVertexBuffer(bufferData, offset: 0, index: 0)

        renderPass.setIndexBuffer(part.indexBuffer, offset: 0)

        renderPass.drawIndexed(
            indexCount: part.indexCount,
            indexBufferOffset: 0,
            instanceCount: 1
        )

        renderPass.endRenderPass()
        commandBuffer.commit()
    }

    private func createQuadMesh() -> Mesh {
        var descriptor = MeshDescriptor(name: "Quad")
        descriptor.primitiveTopology = .triangleList

        let positions: [Vector3] = [
            Vector3(-1, -1, 0),
            Vector3(1, -1, 0),
            Vector3(1, 1, 0),
            Vector3(-1, 1, 0)
        ]
        let uvs: [Vector2] = [
            Vector2(0, 1),
            Vector2(1, 1),
            Vector2(1, 0),
            Vector2(0, 0)
        ]

        let indices: [UInt32] = [0, 1, 2, 0, 2, 3]

        descriptor[MeshDescriptor.positions] = MeshBuffer(positions)
        descriptor[MeshDescriptor.textureCoordinates] = MeshBuffer(uvs)
        descriptor.indicies = indices

        return Mesh.generate(from: [descriptor])
    }

    private func createPipeline(device: RenderDevice, pixelFormat: PixelFormat) throws -> RenderPipeline {
        var descriptor = RenderPipelineDescriptor()
        descriptor.debugName = "Upscale Pipeline"

        let shaderSource = try ShaderSource(source: shaderCode)
        let compiler = ShaderCompiler(shaderSource: shaderSource)
        let vertex = try compiler.compileShader(for: .vertex)
        let fragment = try compiler.compileShader(for: .fragment)

        descriptor.vertex = vertex
        descriptor.fragment = fragment

        descriptor.vertexDescriptor.attributes.append([
            .attribute(.vector3, name: "a_Position"),
            .attribute(.vector2, name: "a_UV")
        ])

        descriptor.vertexDescriptor.layouts[0].stride = MemoryLayout<FullscreenVertexData>.stride

        descriptor.colorAttachments = [
            RenderPipelineColorAttachmentDescriptor(format: pixelFormat)
        ]

        return device.createRenderPipeline(from: descriptor)
    }


    private let shaderCode = """
    #version 450 core
    #pragma stage : vert
    
    layout (location = 0) in vec3 a_Position;
    layout (location = 1) in vec2 a_UV;
    
    layout (location = 0) out vec2 v_UV;
    
    void main() {
        gl_Position = vec4(a_Position, 1.0);
        v_UV = a_UV;
    }
    
    #version 450 core
    #pragma stage : frag
    
    layout (location = 0) in vec2 v_UV;
    layout (location = 0) out vec4 o_Color;
    
    layout (binding = 0) uniform sampler2D u_MainTexture;
    
    void main() {
        o_Color = texture(u_MainTexture, v_UV);
    }
    """
}



/// An object describe 2D render item.
public struct Transparent2DRenderItem: RenderItem {
    
    /// An entity that hold additional information about render item.
    public var entity: Entity.ID

    /// An entity for batch rendering.
    public var batchEntity: Entity.ID

    /// Draw pass which will be used for rendering this item.
    public var drawPass: any DrawPass
    
    /// Render Pipeline for rendering this item.
    public var renderPipeline: RenderPipeline
    
    /// Sort key used for rendering order.
    public var sortKey: Float
    
    /// If item support batch rendering, pass range of indecies.
    public var batchRange: Range<Int32>?

    public init(
        entity: Entity.ID,
        batchEntity: Entity.ID,
        drawPass: any DrawPass,
        renderPipeline: RenderPipeline,
        sortKey: Float,
        batchRange: Range<Int32>? = nil
    ) {
        self.entity = entity
        self.batchEntity = batchEntity
        self.drawPass = drawPass
        self.renderPipeline = renderPipeline
        self.sortKey = sortKey
        self.batchRange = batchRange
    }
}
