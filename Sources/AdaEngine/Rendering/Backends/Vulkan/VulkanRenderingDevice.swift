//
//  VulkanRenderingDevice.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 31.08.2024.
//

#if VULKAN
import CVulkan
import Vulkan
import Math

final class VulkanRenderingDevice: RenderingDevice {

    let device: Device
    let commandPool: CommandPool
    let context: VulkanRenderBackend.Context?

    init(device: Device, commandPool: CommandPool, context: VulkanRenderBackend.Context? = nil) {
        self.device = device
        self.commandPool = commandPool
        self.context = context
    }

    func getImage(from texture: Texture) -> Image? {
        return nil
    }

    func createIndexBuffer(format: IndexBufferFormat, bytes: UnsafeRawPointer, length: Int) -> IndexBuffer {
        do {
            let indexBuffer = try VulkanIndexBuffer(renderingDevice: self, size: length, queueFamilyIndecies: [], indexFormat: format)
            let rawPointer = UnsafeMutableRawPointer(mutating: bytes)
            indexBuffer.setData(rawPointer, byteCount: length)
            return indexBuffer
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createBuffer(length: Int, options: ResourceOptions) -> Buffer {
        do {
            return try VulkanBuffer(
                renderingDevice: self,
                size: length,
                usage: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue,
                queueFamilyIndecies: []
            )
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createBuffer(bytes: UnsafeRawPointer, length: Int, options: ResourceOptions) -> Buffer {
        do {
            let buffer = try VulkanBuffer(
                renderingDevice: self,
                size: length,
                usage: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue,
                queueFamilyIndecies: []
            )
            buffer.setData(UnsafeMutableRawPointer(mutating: bytes), byteCount: length)

            return buffer
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createVertexBuffer(length: Int, binding: Int) -> VertexBuffer {
        do {
            return try VulkanVertexBuffer(
                renderingDevice: self,
                size: length,
                queueFamilyIndecies: [],
                binding: binding
            )
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func compileShader(from shader: Shader) throws -> CompiledShader {
        return try VulkanShader.make(from: shader, device: self.device)
    }

    func createFramebuffer(from descriptor: FramebufferDescriptor) -> Framebuffer {
        return VulkanFramebuffer(device: self.device, descriptor: descriptor)
    }

    func createRenderPipeline(from descriptor: RenderPipelineDescriptor) -> RenderPipeline {
        do {
            return try VulkanRenderPipeline(device: self.device, descriptor: descriptor)
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createSampler(from descriptor: SamplerDescriptor) -> Sampler {
        do {
            return try VulkanSampler(device: self.device, descriptor: descriptor)
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createUniformBuffer(length: Int, binding: Int) -> UniformBuffer {
        do {
            return try VulkanUniformBuffer(renderingDevice: self, size: length, queueFamilyIndecies: [], binding: binding)
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    func createUniformBufferSet() -> UniformBufferSet {
        return GenericUniformBufferSet(frames: RenderEngine.configurations.maxFramesInFlight, device: self)
    }

    func createTexture(from descriptor: TextureDescriptor) -> GPUTexture {
        do {
            return try VulkanGPUTexture(device: self.device, descriptor: descriptor)
        } catch {
            fatalError("[VulkanRenderBackend] Failed to create texture: \(error.localizedDescription)")
        }
    }

    func getGlobalFramebuffer() -> any Framebuffer {
        fatalError("Kek")
    }

    func getImage(for texture2D: RID) -> Image? {
        fatalError("Kek")
    }
}

extension VulkanRenderingDevice {
    func beginDraw(
        for window: UIWindow.ID,
        clearColor: Color,
        loadAction: AttachmentLoadAction,
        storeAction: AttachmentStoreAction
    ) throws -> DrawList {
        guard let window = self.context?.windows[window] else {
            fatalError("Can't find window for draw")
        }

        let framebuffer = window.swapchain.framebuffers[0]
        let vkFramebuffer = VulkanFramebuffer(
            device: self.device,
            framebuffer: framebuffer,
            renderPass: window.swapchain.renderPass
        )

        let renderArea = VkRect2D(
            offset: VkOffset2D(x: 0, y: 0),
            extent: VkExtent2D(width: UInt32(vkFramebuffer.descriptor.width), height: UInt32(vkFramebuffer.descriptor.height))
        )

        let commandBuffer = try self.device.getCommandBuffer(commandPool: self.commandPool)

        commandBuffer.beginRenderPass(
            framebuffer: vkFramebuffer.vkFramebuffer,
            renderArea: renderArea,
            clearColors: [VkClearValue(color: clearColor.toVulkanClearColor)]
        )

        return DrawList(
            commandBuffer: VulkanRenderCommandBuffer(
                framebuffer: vkFramebuffer,
                commandBuffer: commandBuffer
            ),
            renderingDevice: self
        )
    }

    func beginDraw(to framebuffer: Framebuffer, clearColors: [Color]?) throws -> DrawList {
        guard let vulkanFramebuffer = framebuffer as? VulkanFramebuffer else {
            fatalError("Not correct framebuffer object")
        }

        let renderArea = VkRect2D(
            offset: VkOffset2D(x: 0, y: 0),
            extent: VkExtent2D(width: UInt32(framebuffer.descriptor.width), height: UInt32(framebuffer.descriptor.height))
        )

        let clearColors = clearColors ?? [Color.black]

        let commandBuffer = try self.device.getCommandBuffer(commandPool: self.commandPool)

        commandBuffer.beginRenderPass(
            framebuffer: vulkanFramebuffer.vkFramebuffer,
            renderArea: renderArea,
            clearColors: clearColors.map { VkClearValue(color: $0.toVulkanClearColor) }
        )

        return DrawList(
            commandBuffer: VulkanRenderCommandBuffer(
                framebuffer: vulkanFramebuffer,
                commandBuffer: commandBuffer
            ),
            renderingDevice: self
        )
    }

    func draw(_ list: DrawList, indexCount: Int, indexBufferOffset: Int, instanceCount: Int) {
        guard let renderPipeline = list.renderPipeline as? VulkanRenderPipeline else {
            return
        }

        guard let renderCommandBuffer = list.commandBuffer as? VulkanRenderCommandBuffer else {
            return
        }

        let commandBuffer = renderCommandBuffer.commandBuffer

        do {
            // Prepare render pipeline
            try renderPipeline.update(
                for: renderCommandBuffer.framebuffer,
                drawList: list
            )

            try commandBuffer.beginUpdate()

            // Should be in draw settings
            commandBuffer.bindRenderPipeline(renderPipeline.renderPipeline)

            if list.isScissorEnabled {
                let rect = list.scissorRect
                commandBuffer.setScissor([
                    VkRect2D(
                        offset: VkOffset2D(
                            x: Int32(rect.origin.x),
                            y: Int32(rect.origin.y)
                        ),
                        extent: VkExtent2D(
                            width: UInt32(rect.size.width),
                            height: UInt32(rect.size.height)
                        )
                    )
                ])
            }

            if list.isViewportEnabled {
                let viewport = list.viewport
                let rect = viewport.rect
                commandBuffer.setViewport([
                    VkViewport(
                        x: rect.origin.x,
                        y: rect.origin.y,
                        width: rect.size.width,
                        height: rect.size.height,
                        minDepth: viewport.depth.lowerBound,
                        maxDepth: viewport.depth.upperBound
                    )
                ])
            }

            let vertexBuffers = list.vertexBuffers.map { ($0 as! VulkanVertexBuffer).buffer }
            commandBuffer.bindVertexBuffers(
                vertexBuffers,
                firstBinding: 0,
                bindingCount: vertexBuffers.count,
                offsets: [0]
            )

            let textures = list.textures.compactMap { $0 }
            for (index, texture) in textures.enumerated() {
                let mtlTexture = (texture.gpuTexture as! VulkanGPUTexture)
                let mtlSampler = (texture.sampler as! VulkanSampler)

//                encoder.setFragmentTexture(mtlTexture, index: index)
//                encoder.setFragmentSamplerState(mtlSampler, index: index)
            }

            for index in 0 ..< list.uniformBufferCount {
                let data = list.uniformBuffers[index]!
                let buffer = data.buffer as! VulkanUniformBuffer



//                switch data.shaderStage {
//                case .vertex:
//                    encoder.setVertexBuffer(buffer.buffer, offset: 0, index: buffer.binding)
//                case .fragment:
//                    encoder.setFragmentBuffer(buffer.buffer, offset: 0, index: buffer.binding)
//                default:
//                    continue
//                }
            }

            guard let indexBuffer = list.indexBuffer as? VulkanIndexBuffer else {
                return
            }

            commandBuffer.bindIndexBuffer(
                indexBuffer.buffer,
                offset: UInt64(indexBufferOffset),
                indexType: indexBuffer.indexFormat.toVulkan
            )

            commandBuffer.drawIndexed(
                indexCount: indexCount,
                instanceCount: instanceCount,
                firstIndex: 0,
                vertexOffset: 0,
                firstInstance: 1
            )

            try commandBuffer.endUpdate()
        } catch {
            assertionFailure("Failed to draw: \(error)")
        }
    }

    func endDrawList(_ drawList: DrawList) {
        guard let renderCommandBuffer = drawList.commandBuffer as? VulkanRenderCommandBuffer else {
            return
        }

        renderCommandBuffer.commandBuffer.endRenderPass()
    }
}

extension VulkanRenderingDevice {
    func createRenderEncoder(for framebuffer: Framebuffer) throws -> RenderCommandEncoder {
        guard let framebuffer = framebuffer as? VulkanFramebuffer else {
            fatalError()
        }

        let commandBuffer = try self.device.getCommandBuffer(commandPool: self.commandPool)

        let commandEncoder = VulkanRenderCommandEncoder(
            commandBuffer: commandBuffer,
            framebuffer: framebuffer.vkFramebuffer
        )

        let renderArea = VkRect2D(
            offset: VkOffset2D(x: 0, y: 0),
            extent: VkExtent2D(width: UInt32(framebuffer.descriptor.width), height: UInt32(framebuffer.descriptor.height))
        )

        try commandBuffer.beginUpdate()
        commandBuffer.beginRenderPass(
            framebuffer: framebuffer.vkFramebuffer,
            renderArea: renderArea,
            clearColors: []
        )

        return commandEncoder
    }
}

extension VulkanRenderingDevice {
    func draw(
        in commandBuffer: CommandBuffer,
        vertexCount: Int,
        instanceCount: Int,
        baseVertex: Int,
        firstInstance: Int
    ) {
        guard let commandBuffer = commandBuffer as? VulkanCommandBuffer else {
            return
        }

        commandBuffer.buffer.draw(
            vertexCount: vertexCount,
            instanceCount: instanceCount,
            firstVertex: baseVertex,
            firstInstance: firstInstance
        )
    }

    func drawIndexed(
        in commandBuffer: CommandBuffer,
        indexCount: Int,
        instanceCount: Int,
        firstIndex: Int,
        offset: Int,
        firstInstance: Int
    ) {
        guard let commandBuffer = commandBuffer as? VulkanCommandBuffer else {
            return
        }

        commandBuffer.buffer.drawIndexed(
            indexCount: indexCount,
            instanceCount: instanceCount,
            firstIndex: firstIndex,
            vertexOffset: offset,
            firstInstance: firstInstance
        )
    }
}

private extension IndexBufferFormat {
    var toVulkan: VkIndexType {
        switch self {
        case .uInt16: VK_INDEX_TYPE_UINT16
        case .uInt32: VK_INDEX_TYPE_UINT32
        }
    }
}

private extension IndexPrimitive {
    var toVulkan: VkPrimitiveTopology {
        switch self {
        case .triangle:
            VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
        case .triangleStrip:
            VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP
        case .line:
            VK_PRIMITIVE_TOPOLOGY_LINE_LIST
        case .lineStrip:
            VK_PRIMITIVE_TOPOLOGY_LINE_STRIP
        case .points:
            VK_PRIMITIVE_TOPOLOGY_POINT_LIST
        }
    }
}

private extension TriangleFillMode {
    var toVulkan: VkPolygonMode {
        switch self {
        case .fill:
            VK_POLYGON_MODE_FILL
        case .lines:
            VK_POLYGON_MODE_LINE
        }
    }
}

private extension Color {
    var toVulkanClearColor: VkClearColorValue {
        VkClearColorValue(float32: (self.red, self.green, self.blue, self.alpha))
    }
}

struct VulkanCommandBuffer: CommandBuffer {
    let buffer: Vulkan.CommandBuffer
}

class VulkanRenderCommandBuffer: DrawCommandBuffer {
    let framebuffer: VulkanFramebuffer
    let commandBuffer: Vulkan.CommandBuffer

    init(
        framebuffer: VulkanFramebuffer,
        commandBuffer: Vulkan.CommandBuffer
    ) {
        self.commandBuffer = commandBuffer
        self.framebuffer = framebuffer
    }
}

final class VulkanRenderCommandEncoder: RenderCommandEncoder {

    let commandBuffer: Vulkan.CommandBuffer
    let framebuffer: VKFramebuffer

    init(commandBuffer: Vulkan.CommandBuffer, framebuffer: VKFramebuffer) {
        self.commandBuffer = commandBuffer
        self.framebuffer = framebuffer
    }

    func setRenderPipeline(_ renderPipeline: RenderPipeline) {
        guard let renderPipeline = renderPipeline as? VulkanRenderPipeline else {
            return
        }

        self.commandBuffer.bindRenderPipeline(renderPipeline.renderPipeline)
    }

    func pushDebugGroup(_ name: String) {

    }

    func popDebugGroup() {

    }

    func setVertexBuffers(_ buffers: [VertexBuffer], offsets: [Int], index: Int) {
        let vulkanBuffers = buffers.compactMap {
            ($0 as? VulkanBuffer)?.buffer
        }
//        self.commandBuffer.bindVertexBuffers(vulkanBuffers, firstBinding: 0, bindingCount: 0, offsets: offsets)
    }

    func setViewports(_ viewports: [Viewport]) {
        self.commandBuffer.setViewport(viewports.map {
            VkViewport(
                x: $0.rect.origin.x,
                y: $0.rect.origin.y,
                width: $0.rect.size.width,
                height: $0.rect.size.height,
                minDepth: $0.depth.lowerBound,
                maxDepth: $0.depth.upperBound
            )
        })
    }

    func endEncoding() {
        self.commandBuffer.endRenderPass()
        try! self.commandBuffer.endUpdate()
    }

    func setScissors(_ rects: [Rect]) {
        self.commandBuffer.setScissor(rects.map {
            VkRect2D(
                offset: VkOffset2D(x: Int32($0.origin.x), y: Int32($0.origin.y)),
                extent: VkExtent2D(width: UInt32($0.size.width), height: UInt32($0.size.height))
            )
        })
    }

    func setIndexBuffer(_ buffer: IndexBuffer, offset: Int) {
        guard let indexBuffer = buffer as? VulkanIndexBuffer else {
            assertionFailure("IndexBuffer isn't an instance of VulkanIndexBuffer.")
            return
        }
//
//        VkDescriptorSetLayoutBinding(
//            binding: <#T##UInt32#>,
//            descriptorType: VkDescriptorType,
//            descriptorCount: <#T##UInt32#>,
//            stageFlags: <#T##VkShaderStageFlags#>,
//            pImmutableSamplers: <#T##UnsafePointer<VkSampler?>!#>
//        )

        self.commandBuffer.bindIndexBuffer(indexBuffer.buffer, offset: UInt64(offset), indexType: indexBuffer.indexFormat.toVulkan)
    }

    func setLineWidth(_ width: Float) {
        self.commandBuffer.setLineWidth(width)
    }

    func drawIndexed(
        vertexCount: Int,
        instanceCount: Int,
        baseVertex: Int,
        firstInstance: Int
    ) {

    }

    func drawIndexed(
        indexCount: Int,
        instanceCount: Int,
        firstIndex: Int,
        offset: Int,
        firstInstance: Int
    ) {
        self.commandBuffer.drawIndexed(
            indexCount: indexCount,
            instanceCount: instanceCount,
            firstIndex: firstIndex,
            vertexOffset: offset,
            firstInstance: firstInstance
        )
    }
}

#endif
