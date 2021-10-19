//
//  VulkanRenderContext.swift
//  
//
//  Created by v.prusakov on 8/15/21.
//

import Vulkan
import CVulkan
import Math
import simd

public let NotFound = Int.max

struct QueueFamilyIndices {
    let graphicsIndex: Int
    let presentationIndex: Int
    let isSeparate: Bool
}

struct Uniforms {
    let modelMatrix: Transform
    let viewMatrix: Transform
    let projectionMatrix: Transform
}

struct Vertex {
    let pos: Vector2
    let color: Vector3
    
    static func getBindingDescription() -> VkVertexInputBindingDescription {
        return VkVertexInputBindingDescription(
            binding: 0,
            stride: UInt32(MemoryLayout<Vertex>.stride),
            inputRate: VK_VERTEX_INPUT_RATE_VERTEX
        )
    }
    
    static func getAttributeDescriptions() -> [VkVertexInputAttributeDescription] {
        var attributeDescriptions = [VkVertexInputAttributeDescription].init(repeating: VkVertexInputAttributeDescription(), count: 2)
        
        attributeDescriptions[0].binding = 0
        attributeDescriptions[0].location = 0
        attributeDescriptions[0].format = VK_FORMAT_R32G32_SFLOAT
        attributeDescriptions[0].offset = UInt32(MemoryLayout.offset(of: \Vertex.pos)!)
        
        attributeDescriptions[1].binding = 0
        attributeDescriptions[1].location = 1
        attributeDescriptions[1].format = VK_FORMAT_R32G32B32_SFLOAT
        attributeDescriptions[1].offset = UInt32(MemoryLayout.offset(of: \Vertex.color)!)
        
        return attributeDescriptions
    }
}

let vertecies: [Vertex] = [
    Vertex(pos: [-0.5, -0.5], color: [1, 0, 0]),
    Vertex(pos: [0.5, -0.5], color: [0, 1, 0]),
    Vertex(pos: [0.5, 0.5], color: [0, 0, 1]),
    Vertex(pos: [-0.5, 0.5], color: [0.1, 0, 1]),
]

let indecies: [UInt16] = [0, 1, 2, 2, 3, 0]

public class VulkanRenderContext {
    
    public private(set) var vulkan: VulkanInstance!
    private var queueFamilyIndicies: QueueFamilyIndices!
    public private(set) var device: Device!
    public private(set) var surface: Surface!
    public private(set) var gpu: PhysicalDevice!
    
    private var graphicsQueue: Queue!
    private var presentQueue: Queue!
    
    private var imageFormat: VkFormat!
    private var colorSpace: VkColorSpaceKHR!
    
    private(set) var renderPass: RenderPass!
    var graphicsPipeline: RenderPipeline!
    var pipelineLayout: PipelineLayout!
    private(set) var swapchain: Swapchain!
    public private(set) var framebuffers: [Framebuffer] = []
    public private(set) var imageViews: [ImageView] = []
    
    private(set) var commandPool: CommandPool!
    private(set) var commandBuffers: [CommandBuffer] = []
    
    var imageAvailableSemaphores: [Vulkan.Semaphore] = []
    var renderFinishedSemaphores: [Vulkan.Semaphore] = []
    
    var inFlightFences: [Fence] = []
    var imagesInFlight: [Fence?] = []
    
    var maxFramesInFlight: UInt32 = 2
    
    var framebufferSize: Vector2i = Vector2i(0, 0)
    public var framebufferResized = false
    
    public let vulkanVersion: UInt32
    
    public var currentImageIndex: UInt32 = 0
    public var currentFrame: UInt32 = 0
    
    var vertexBuffer: Buffer!
    var indexBuffer: Buffer!
    var unifformBuffers: [Buffer] = []
    var unifformBuffersMemory: [VkDeviceMemory] = []
    
    var descriptorSetLayout: DescriptorSetLayout!
    var descriptorPool: DescriptorPool!
    var descriptorSets: [DescriptorSet] = []
    
    public required init() {
        self.vulkanVersion = Self.determineVulkanVersion()
    }
    
    public func initialize(with appName: String) throws {
        let vulkan = try self.createInstance(appName: appName)
        self.vulkan = vulkan
        
        let gpu = try self.createGPU()
        self.gpu = gpu
    }
    
    public func updateSwapchain(for size: Vector2i) throws {
        if self.swapchain != nil {
            try self.destroySwapchain()
        }
        
        try self.createSwapchain(for: size)
    }
    
    public func prepareBuffer() throws {
        let fence = self.inFlightFences[self.currentFrame]
        try fence.wait()
        
        var imageIndex: UInt32 = 0
        let acquireResult = self.swapchain.acquireNextImage(semaphore: self.imageAvailableSemaphores[currentFrame], nextImageIndex: &imageIndex)
        
        if acquireResult == VK_ERROR_OUT_OF_DATE_KHR {
            try self.updateSwapchain(for: self.framebufferSize)
            return
        } else if acquireResult != VK_SUCCESS && acquireResult != VK_SUBOPTIMAL_KHR {
            throw AdaError("failed to acquire swap chain image!")
        }
        
        try updateUniformBuffer(imageIndex: imageIndex)
        
        if self.imagesInFlight.indices.contains(Int(imageIndex)) {
            try self.imagesInFlight[imageIndex]?.wait()
        }
        
        self.imagesInFlight[imageIndex] = self.inFlightFences[currentFrame]
        
        let waitSemaphores = [self.imageAvailableSemaphores[currentFrame]]
        let signalSemaphores = [self.imageAvailableSemaphores[currentFrame]]
        let commandBuffers = [self.commandBuffers[imageIndex]]
        try inFlightFences[currentFrame].reset()
        
        try self.graphicsQueue.submit(
            commandsBuffers: commandBuffers,
            waitSemaphores: waitSemaphores,
            signalSemaphores: signalSemaphores,
            stageFlags: [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue],
            fence: self.inFlightFences[currentFrame]
        )
        
        try self.presentQueue.present(
            swapchains: [self.swapchain],
            waitSemaphores: waitSemaphores,
            imageIndex: imageIndex
        )
        
        self.currentFrame = (currentFrame + 1) % self.maxFramesInFlight
    }
    
    public func flush() throws {
        //        let index = Int(currentImageIndex)
        //
        //        let commandBuffer = self.commandBuffers[index]
        //        self.renderPass.end(for: commandBuffer)
        //        try commandBuffer.endUpdate()
    }
    
    // MARK: - Private
    
    private func createInstance(appName: String) throws -> VulkanInstance {
        let extensions = try Self.provideExtensions()
        
        let appInfo = VkApplicationInfo(
            sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
            pNext: nil,
            pApplicationName: appName,
            applicationVersion: 0, // TODO: pass app version
            pEngineName: "Ada Engine",
            engineVersion: 0, // TODO: pass engine version
            apiVersion: vulkanVersion
        )
        
        let info = InstanceCreateInfo(
            applicationInfo: appInfo,
            // TODO: Add enabledLayers flag to manage layers
            enabledLayerNames: ["VK_LAYER_KHRONOS_validation"],
            enabledExtensionNames: extensions.map(\.extensionName)
        )
        
        return try VulkanInstance(info: info)
    }
    
    private func createWindow(surface: Surface, size: Vector2i) throws {
        if self.graphicsQueue == nil && self.presentQueue == nil {
            try self.createQueues(gpu: self.gpu, surface: surface)
        }
        
        self.surface = surface
        
        try self.createSwapchain(for: size)
    }
    
    private func createGPU() throws -> PhysicalDevice {
        let devices = try vulkan.physicalDevices()
        
        if devices.isEmpty {
            throw AdaError("Could not find any compitable devices for Vulkan. Do you have a compitable Vulkan devices?")
        }
        
        let preferredGPU =
            devices.first(where: { $0.properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU }) ?? devices[0]
        
        return preferredGPU
    }
    
    private func createQueues(gpu: PhysicalDevice, surface: Surface) throws {
        let queues = gpu.getQueueFamily()
        
        if queues.isEmpty {
            throw AdaError("Could not find any queues for selected GPU.")
        }
        
        let supporterPresentationQueues = try queues.map { try gpu.supportSurface(surface, queueFamily: $0) }
        
        var presentationQueueIndex = NotFound
        var graphicsQueueIndex = NotFound
        
        for (index, queue) in queues.enumerated() {
            if queue.queueFlags.contains(.graphicsBit) && graphicsQueueIndex == NotFound {
                graphicsQueueIndex = index
            }
            
            if supporterPresentationQueues[index] == true {
                graphicsQueueIndex = index
                presentationQueueIndex = index
                break
            }
        }
        
        // We dont find presentation queue
        if
            presentationQueueIndex == NotFound,
            let index = supporterPresentationQueues.firstIndex(where: { $0 == true })
        {
            presentationQueueIndex = index
        }
        
        assert(presentationQueueIndex != NotFound || graphicsQueueIndex != NotFound, "Presentation and/or graphics queues not found")
        
        let indecies = QueueFamilyIndices(
            graphicsIndex: graphicsQueueIndex,
            presentationIndex: presentationQueueIndex,
            isSeparate: graphicsQueueIndex != presentationQueueIndex
        )
        
        self.queueFamilyIndicies = indecies
        
        let device = try self.createDevice(for: gpu, surface: surface, queueIndecies: indecies)
        self.device = device
        
        self.graphicsQueue = device.getQueue(at: indecies.graphicsIndex)
        self.presentQueue = indecies.isSeparate ? device.getQueue(at: indecies.presentationIndex) : self.graphicsQueue
    }
    
    private func destroySwapchain() throws {
        try self.device.waitIdle()
        self.framebuffers = []
        self.commandBuffers = []
        self.graphicsPipeline = nil
        self.renderPass = nil
        self.imageViews = []
        self.swapchain = nil
    }
    
    private func createDescriptorSetLayout() throws {
        var bindings = VkDescriptorSetLayoutBinding(
            binding: 0,
            descriptorType: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            descriptorCount: 1,
            stageFlags: VK_SHADER_STAGE_VERTEX_BIT.rawValue,
            pImmutableSamplers: nil)
        
        let layoutInfo = VkDescriptorSetLayoutCreateInfo(
            sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            pNext: nil,
            flags: 0,
            bindingCount: 1,
            pBindings: &bindings
        )
        
        self.descriptorSetLayout = try DescriptorSetLayout(device: self.device, layoutInfo: layoutInfo)
    }
    
    private func createSwapchain(for size: Vector2i) throws {
        let surfaceCapabilities = try self.gpu.surfaceCapabilities(for: self.surface)
        
        var imageFormat = VK_FORMAT_B8G8R8A8_UNORM
        var colorSpace: VkColorSpaceKHR
        
        let formats = try self.gpu.surfaceFormats(for: self.surface)
        
        if formats.isEmpty {
            throw AdaError("Surface formats not found")
        }
        
        if formats.count == 1 && formats[0].format == VK_FORMAT_UNDEFINED {
            imageFormat = VK_FORMAT_B8G8R8A8_UNORM
            colorSpace = formats[0].colorSpace
        } else {
            let availableFormats = [VK_FORMAT_B8G8R8A8_UNORM, VK_FORMAT_R8G8B8A8_UNORM]
            
            guard let preferredFormat = formats.first(where: { availableFormats.contains($0.format) }) else {
                throw AdaError("Not found supported format")
            }
            
            colorSpace = preferredFormat.colorSpace
            imageFormat = preferredFormat.format
        }
        
        let extent: VkExtent2D
        
        if surfaceCapabilities.currentExtent.width != UInt32.max {
            extent = surfaceCapabilities.currentExtent
        } else {
            extent = VkExtent2D(width: UInt32(size.x), height: UInt32(size.y))
        }
        
        let swapchainPresentMode = VK_PRESENT_MODE_FIFO_KHR
        
        let imageCount = surfaceCapabilities.minImageCount + 1 // TODO: Change it for latter
        
        let preTransform: VkSurfaceTransformFlagsKHR
        if (surfaceCapabilities.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR.rawValue) == true {
            preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR.rawValue
        } else {
            preTransform = surfaceCapabilities.supportedTransforms
        }
        
        let availableCompositionAlpha = [VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
                                         VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR,
                                         VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR]
        
        let compositionAlpha = availableCompositionAlpha.first {
            (surfaceCapabilities.supportedCompositeAlpha & $0.rawValue) == true
        } ?? VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
        
        let swapchainInfo = VkSwapchainCreateInfoKHR(
            sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            pNext: nil,
            flags: 0,
            surface: surface.rawPointer,
            minImageCount: imageCount,
            imageFormat: imageFormat,
            imageColorSpace: colorSpace,
            imageExtent: extent,
            imageArrayLayers: 1,
            imageUsage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue,
            imageSharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil,
            preTransform: VkSurfaceTransformFlagBitsKHR(rawValue: preTransform),
            compositeAlpha: compositionAlpha,
            presentMode: swapchainPresentMode,
            clipped: true,
            oldSwapchain: nil)
        
        let swapchain = try Swapchain(device: self.device, createInfo: swapchainInfo)
        self.swapchain = swapchain
        
        self.imageFormat = imageFormat
        self.colorSpace = colorSpace
        
        let images = try swapchain.getImages()
        
        for image in images {
            let info = VkImageViewCreateInfo(
                sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                pNext: nil,
                flags: 0,
                image: image,
                viewType: VK_IMAGE_VIEW_TYPE_2D,
                format: imageFormat,
                components: VkComponentMapping(
                    r: VK_COMPONENT_SWIZZLE_R,
                    g: VK_COMPONENT_SWIZZLE_G,
                    b: VK_COMPONENT_SWIZZLE_B,
                    a: VK_COMPONENT_SWIZZLE_A
                ),
                subresourceRange: VkImageSubresourceRange(
                    aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                    baseMipLevel: 0,
                    levelCount: 1,
                    baseArrayLayer: 0,
                    layerCount: 1
                )
            )
            
            let imageView = try ImageView(device: self.device, info: info)
            self.imageViews.append(imageView)
        }
        
        let extentSize = Vector2i(Int(extent.width), Int(extent.height))
        
        self.framebufferSize = extentSize
        
        try self.createRenderPass(size: extentSize)
        try self.createDescriptorSetLayout()
        try self.createRenderPipeline(size: extentSize)
        try self.createFramebuffer(size: extentSize)
        try self.createCommandPool()
        try self.createVertexBuffer()
        try self.createIndexBuffer()
        try self.createUniformBuffers()
        try self.createDescriptorPool()
        try self.createDescriptorSets()
        try self.createCommandBuffers()
        try self.createSyncObjects()
    }
    
    func createRenderPipeline(size: Vector2i) throws {
        let shaders = try self.loadShaders()
        
        var vertDesc = Vertex.getBindingDescription()
        var vertAttr = Vertex.getAttributeDescriptions()
        
        var vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            vertexBindingDescriptionCount: 1,
            pVertexBindingDescriptions: &vertDesc,
            vertexAttributeDescriptionCount: UInt32(vertAttr.count),
            pVertexAttributeDescriptions: &vertAttr
        )
        
        var inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            primitiveRestartEnable: false
        )
        
        var viewPort = VkViewport(x: 0, y: 0, width: Float(size.x), height: Float(size.y), minDepth: 0, maxDepth: 1)
        var scissor = VkRect2D(offset: VkOffset2D(x: 0, y: 0), extent: self.swapchain.extent)
        
        var viewportState = VkPipelineViewportStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            viewportCount: 1,
            pViewports: &viewPort,
            scissorCount: 1,
            pScissors: &scissor
        )
        
        var rasterizer = VkPipelineRasterizationStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            depthClampEnable: false,
            rasterizerDiscardEnable: false,
            polygonMode: VK_POLYGON_MODE_FILL,
            cullMode: VK_CULL_MODE_BACK_BIT.rawValue,
            frontFace: VK_FRONT_FACE_CLOCKWISE,
            depthBiasEnable: false,
            depthBiasConstantFactor: 0,
            depthBiasClamp: 0,
            depthBiasSlopeFactor: 0,
            lineWidth: 1.0
        )
        
        var multisampling = VkPipelineMultisampleStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
            sampleShadingEnable: false,
            minSampleShading: 1,
            pSampleMask: nil,
            alphaToCoverageEnable: false,
            alphaToOneEnable: false
        )
        
        var colorBlendAttachment = VkPipelineColorBlendAttachmentState(
            blendEnable: false,
            srcColorBlendFactor: VK_BLEND_FACTOR_ONE,
            dstColorBlendFactor: VK_BLEND_FACTOR_ZERO,
            colorBlendOp: VK_BLEND_OP_ADD,
            srcAlphaBlendFactor: VK_BLEND_FACTOR_ONE,
            dstAlphaBlendFactor: VK_BLEND_FACTOR_ZERO,
            alphaBlendOp: VK_BLEND_OP_ADD,
            colorWriteMask: VK_COLOR_COMPONENT_R_BIT.rawValue | VK_COLOR_COMPONENT_G_BIT.rawValue | VK_COLOR_COMPONENT_B_BIT.rawValue | VK_COLOR_COMPONENT_A_BIT.rawValue
        )
        
        var colorBlending = VkPipelineColorBlendStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            logicOpEnable: false,
            logicOp: VK_LOGIC_OP_COPY,
            attachmentCount: 1,
            pAttachments: &colorBlendAttachment,
            blendConstants: (0, 0, 0, 0)
        )
        //
        //        var dynamicState = VkPipelineDynamicStateCreateInfo(
        //            sType: VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        //            pNext: nil,
        //            flags: 0,
        //            dynamicStateCount: 2,
        //            pDynamicStates: [VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_LINE_WIDTH]
        //        )
        
        var stages = shaders.stages
        
        let pipelineLayout = try PipelineLayout(device: self.device, layouts: [self.descriptorSetLayout])
        let pipelineInfo = VkGraphicsPipelineCreateInfo(
            sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stageCount: UInt32(stages.count),
            pStages: &stages,
            pVertexInputState: &vertexInputInfo,
            pInputAssemblyState: &inputAssembly,
            pTessellationState: nil,
            pViewportState: &viewportState,
            pRasterizationState: &rasterizer,
            pMultisampleState: &multisampling,
            pDepthStencilState: nil,
            pColorBlendState: &colorBlending,
            pDynamicState: nil,
            layout: pipelineLayout.rawPointer,
            renderPass: self.renderPass.rawPointer,
            subpass: 0,
            basePipelineHandle: nil,
            basePipelineIndex: -1)
        
        
        let renderPipeline = try RenderPipeline(
            device: self.device,
            pipelineLayout: pipelineLayout,
            graphicCreateInfo: pipelineInfo
        )
        
        self.graphicsPipeline = renderPipeline
        self.pipelineLayout = pipelineLayout
    }
    
    private func loadShaders() throws -> VulkanShader {
        let frag = try! Data(contentsOf: Bundle.module.url(forResource: "shader.frag", withExtension: "spv")!)
        let vert = try! Data(contentsOf: Bundle.module.url(forResource: "shader.vert", withExtension: "spv")!)
        let vertModule = try ShaderModule(device: self.device, shaderData: vert)
        let fragModule = try ShaderModule(device: self.device, shaderData: frag)
        
        let vertStage = VkPipelineShaderStageCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stage: VK_SHADER_STAGE_VERTEX_BIT,
            module: vertModule.rawPointer,
            pName: ("main" as NSString).utf8String,
            pSpecializationInfo: nil
        )
        
        let fragStage = VkPipelineShaderStageCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stage: VK_SHADER_STAGE_FRAGMENT_BIT,
            module: fragModule.rawPointer,
            pName: ("main" as NSString).utf8String,
            pSpecializationInfo: nil
        )
        
        return VulkanShader(modules: [vertModule, fragModule], stages: [vertStage, fragStage])
    }
    
    private func createDevice(for gpu: PhysicalDevice, surface: Surface, queueIndecies: QueueFamilyIndices) throws -> Device {
        
        let deviceExtensions = try gpu.getExtensions()
        var availableExtenstions = [ExtensionProperties]()
        
        for ext in deviceExtensions {
            if ext.extensionName == VK_KHR_SWAPCHAIN_EXTENSION_NAME {
                availableExtenstions.append(ext)
            }
        }
        
        let properties: [Float] = [0.0]
        
        var queueCreateInfos = [DeviceQueueCreateInfo]()
        queueCreateInfos.append(
            DeviceQueueCreateInfo(
                queueFamilyIndex: UInt32(queueIndecies.graphicsIndex),
                flags: .none,
                queuePriorities: properties
            )
        )
        
        if queueIndecies.isSeparate {
            queueCreateInfos.append(
                DeviceQueueCreateInfo(
                    queueFamilyIndex: UInt32(queueIndecies.presentationIndex),
                    flags: .none,
                    queuePriorities: properties
                )
            )
        }
        
        var features = gpu.features
        features.robustBufferAccess = false
        
        let info = DeviceCreateInfo(
            enabledExtensions: availableExtenstions.map(\.extensionName),
            layers: [],
            queueCreateInfo: queueCreateInfos,
            enabledFeatures: features
        )
        
        return try Device(physicalDevice: gpu, createInfo: info)
    }
    
    private func createRenderPass(size: Vector2i) throws {
        var colorAttachment = VkAttachmentDescription(
            flags: 0,
            format: self.imageFormat,
            samples: VK_SAMPLE_COUNT_1_BIT,
            loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
            storeOp: VK_ATTACHMENT_STORE_OP_STORE,
            stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
            finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        )
        
        //        let depthFormat = try self.getGPUDepthFormat()
        //
        //        let depthAttachment = VkAttachmentDescription(
        //            flags: 0,
        //            format: depthFormat,
        //            samples: VK_SAMPLE_COUNT_1_BIT,
        //            loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
        //            storeOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        //            stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        //            stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        //            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
        //            finalLayout: VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
        //        )
        
        var colorDescription = VkAttachmentReference(
            attachment: 0,
            layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        )
        
        var subpass = VkSubpassDescription(
            flags: 0,
            pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
            inputAttachmentCount: 0,
            pInputAttachments: nil,
            colorAttachmentCount: 1,
            pColorAttachments: &colorDescription,
            pResolveAttachments: nil,
            pDepthStencilAttachment: nil,
            preserveAttachmentCount: 0,
            pPreserveAttachments: nil
        )
        
        let renderPassCreateInfo = VkRenderPassCreateInfo(
            sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            pNext: nil,
            flags: 0,
            attachmentCount: 1,
            pAttachments: &colorAttachment,
            subpassCount: 1,
            pSubpasses: &subpass,
            dependencyCount: 0,
            pDependencies: nil
        )
        
        let renderPass = try RenderPass(device: self.device, createInfo: renderPassCreateInfo)
        self.renderPass = renderPass
    }
    
    private func createFramebuffer(size: Vector2i) throws {
        for imageView in self.imageViews {
            var attachment = imageView.rawPointer
            
            let createInfo = VkFramebufferCreateInfo(
                sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                pNext: nil,
                flags: 0,
                renderPass: self.renderPass.rawPointer,
                attachmentCount: 1,
                pAttachments: &attachment,
                width: UInt32(size.x),
                height: UInt32(size.y),
                layers: 1
            )
            
            let framebuffer = try Framebuffer(device: self.device, createInfo: createInfo)
            self.framebuffers.append(framebuffer)
        }
    }
    
    private func createCommandPool() throws {
        let commandPool = try CommandPool(
            device: self.device,
            queueFamilyIndex: UInt32(self.queueFamilyIndicies.graphicsIndex)
        )
        
        self.commandPool = commandPool
    }
    
    private func createCommandBuffers() throws {
        self.commandBuffers.removeAll()
        
        let allocInfo = VkCommandBufferAllocateInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            pNext: nil,
            commandPool: self.commandPool.rawPointer,
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: UInt32(self.imageViews.count)
        )
        
        let commandBuffers = try CommandBuffer.allocateCommandBuffers(for: self.device, commandPool: self.commandPool, info: allocInfo)
        self.commandBuffers = commandBuffers
        
        for index in 0..<commandBuffers.count {
            let commandBuffer = commandBuffers[index]
            try commandBuffer.beginUpdate()
            
            let framebuffer = self.framebuffers[index]

            self.renderPass.begin(
                for: commandBuffer,
                framebuffer: framebuffer,
                swapchain: self.swapchain
            )
            
            self.graphicsPipeline.bind(for: commandBuffer)
            
            commandBuffer.bindVertexBuffers([self.vertexBuffer], offsets: [0])
            commandBuffer.bindIndexBuffer(self.indexBuffer, offset: 0, indexType: VK_INDEX_TYPE_UINT16)
            commandBuffer.bindDescriptSets(
                pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
                layout: self.pipelineLayout,
                firstSet: 0,
                descriptorSets: [descriptorSets[index]]
            )
//            commandBuffer.draw(vertexCount: vertecies.count, instanceCount: 1, firstVertex: 0, firstInstance: 0)
            commandBuffer.drawIndexed(indexCount: indecies.count, instanceCount: 1, firstIndex: 0, vertexOffset: 0, firstInstance: 0)
            
            self.renderPass.end(for: commandBuffer)
            
            try commandBuffer.endUpdate()
            
            self.commandBuffers.append(commandBuffer)
        }
    }
    
    private func createSyncObjects() throws {
        self.imageAvailableSemaphores.removeAll()
        self.renderFinishedSemaphores.removeAll()
        
        self.imagesInFlight = [Fence?].init(repeating: nil, count: self.imageViews.count)
        
        for _ in 0..<self.maxFramesInFlight {
            self.imageAvailableSemaphores.append(try Vulkan.Semaphore(device: self.device))
            self.renderFinishedSemaphores.append(try Vulkan.Semaphore(device: self.device))
            
            self.inFlightFences.append(try Fence(device: self.device))
        }
    }
    
    private func getGPUDepthFormat() throws -> VkFormat {
        let prefferedFormats = [VK_FORMAT_D32_SFLOAT, VK_FORMAT_D24_UNORM_S8_UINT, VK_FORMAT_D32_SFLOAT_S8_UINT]
        
        let flags = VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT.rawValue
        
        for format in prefferedFormats {
            var properties = VkFormatProperties()
            vkGetPhysicalDeviceFormatProperties(self.gpu.pointer, format, &properties)
            
            if (properties.optimalTilingFeatures & flags) == flags || ((properties.linearTilingFeatures & flags) == flags) {
                return format
            }
        }
        
        throw AdaError("Preffered Depth Format not found")
    }
    
    // MARK: - Test
    
    private func createIndexBuffer() throws {
        let bufferSize = MemoryLayout.size(ofValue: indecies[0]) * indecies.count
        
        let (stagingBuffer, stagingBufferMemory) = try self.createBuffer(
            usage: .transferSource,
            size: bufferSize,
            properties: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue
        )
        
        let mem = try stagingBuffer.mapMemory(stagingBufferMemory, offset: 0, flags: 0)
        stagingBuffer.copy(from: indecies, to: mem)
        stagingBuffer.unmapMemory(stagingBufferMemory)
        
        let (indexBuffer, _) = try self.createBuffer(
            usage: [.indexBuffer, .transferDestination],
            size: bufferSize,
            properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT.rawValue
        )
        
        try indexBuffer.copyBuffer(
            from: stagingBuffer,
            size: bufferSize,
            commandPool: self.commandPool,
            graphicsQueue: graphicsQueue
        )
        
        self.indexBuffer = indexBuffer
        vkFreeMemory(self.device.rawPointer, stagingBufferMemory, nil)
    }
    
    #warning("Test")
    private func createVertexBuffer() throws {
        let bufferSize = MemoryLayout<Vertex>.size * vertecies.count
        
        let (stagingBuffer, stagingBufferMemory) = try self.createBuffer(
            usage: .transferSource,
            size: bufferSize,
            properties: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue
        )
        
        let mem = try stagingBuffer.mapMemory(stagingBufferMemory, offset: 0, flags: 0)
        stagingBuffer.copy(from: vertecies, to: mem)
        stagingBuffer.unmapMemory(stagingBufferMemory)
        
        let (vertexBuffer, _) = try self.createBuffer(
            usage: [.vertexBuffer, .transferDestination],
            size: bufferSize,
            properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT.rawValue
        )
        
        try vertexBuffer.copyBuffer(
            from: stagingBuffer,
            size: bufferSize,
            commandPool: self.commandPool,
            graphicsQueue: graphicsQueue
        )
        
        self.vertexBuffer = vertexBuffer
        vkFreeMemory(self.device.rawPointer, stagingBufferMemory, nil)
    }
    
    private func createUniformBuffers() throws {
        
        self.unifformBuffers.removeAll()
        self.unifformBuffersMemory.removeAll()
        
        for _ in try self.swapchain.getImages() {
            let (buffer, memory) = try self.createBuffer(
                usage: .uniformBuffer,
                size: MemoryLayout<Uniforms>.size,
                properties: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue
            )
            
            self.unifformBuffers.append(buffer)
            self.unifformBuffersMemory.append(memory)
        }
    }
    
    private func updateUniformBuffer(imageIndex: UInt32) throws {
        let time = Time.deltaTime
        
        let uniform = Uniforms(
            modelMatrix: Transform(scale: Vector3(0, 1 * time, 0)),
            viewMatrix: .identity,
            projectionMatrix: .identity
        )
        
        let buffer = unifformBuffers[imageIndex]
        let mem = try buffer.mapMemory(unifformBuffersMemory[imageIndex], offset: 0, flags: 0)
        buffer.copy(from: uniform, to: mem)
        buffer.unmapMemory(unifformBuffersMemory[imageIndex])
    }
    
    private func createDescriptorPool() throws {
        var poolSize = VkDescriptorPoolSize(
            type: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            descriptorCount: UInt32(try self.swapchain.getImages().count)
        )
        
        let info = VkDescriptorPoolCreateInfo(
            sType: VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            pNext: nil,
            flags: 0,
            maxSets: UInt32(try self.swapchain.getImages().count),
            poolSizeCount: 1,
            pPoolSizes: &poolSize
        )
        
        self.descriptorPool = try DescriptorPool(device: self.device, createInfo: info)
    }
    
    private func createDescriptorSets() throws {
        let imagesCount = try self.swapchain.getImages().count
        var layouts: [VkDescriptorSetLayout?] = [VkDescriptorSetLayout?].init(repeating: self.descriptorSetLayout.rawPointer, count: imagesCount)
        
        let info = VkDescriptorSetAllocateInfo(
            sType: VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            pNext: nil,
            descriptorPool: self.descriptorPool.rawPointer,
            descriptorSetCount: UInt32(imagesCount),
            pSetLayouts: &layouts
        )
        
        let descriptorSets = try! DescriptorSet.allocateSets(device: self.device, info: info, count: layouts.count)
        
        for i in 0..<imagesCount {
            var bufferInfo = VkDescriptorBufferInfo(
                buffer: self.unifformBuffers[i].rawPointer,
                offset: 0,
                range: VkDeviceSize(MemoryLayout<Uniforms>.size)
            )
            
            var write = VkWriteDescriptorSet(
                sType: VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                pNext: nil,
                dstSet: descriptorSets[i].rawPointer,
                dstBinding: 0,
                dstArrayElement: 0,
                descriptorCount: 1,
                descriptorType: VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                pImageInfo: nil,
                pBufferInfo: &bufferInfo,
                pTexelBufferView: nil
            )
            
            vkUpdateDescriptorSets(self.device.rawPointer, 1, &write, 0, nil)
        }
        
        self.descriptorSets = descriptorSets
    }
    
    private func createBuffer(usage: Buffer.Usage, size: Int, properties: VkMemoryPropertyFlags) throws -> (Buffer, VkDeviceMemory) {
        let buffer = try Buffer(
            device: self.device,
            size: size,
            usage: usage,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE
        )
        
        let index = try buffer.findMemoryTypeIndex(for: properties, in: self.gpu)
        let allocatedMemory = try buffer.allocateMemory(memoryTypeIndex: index)
        try buffer.bindMemory(allocatedMemory)
        
        return (buffer, allocatedMemory)
    }
}

extension VulkanRenderContext {
    
    private static func determineVulkanVersion() -> UInt32 {
        var version: UInt32 = UInt32.max
        let result = vkEnumerateInstanceVersion(&version)
        
        if result != VK_SUCCESS {
            fatalError("Vulkan API got error when trying get sdk version")
        }
        
        return version
    }
    
    private static func provideExtensions() throws -> [ExtensionProperties] {
        let extensions = try VulkanInstance.getExtensions()
        
        var availableExtenstions = [ExtensionProperties]()
        var isSurfaceFound = false
        var isPlatformExtFound = false
        
        for ext in extensions {
            if ext.extensionName == VK_KHR_SURFACE_EXTENSION_NAME {
                isSurfaceFound = true
                availableExtenstions.append(ext)
            }
            
            if ext.extensionName == Self.platformSpecificSurfaceExtensionName {
                availableExtenstions.append(ext)
                isPlatformExtFound = true
            }
            
            if ext.extensionName == VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME {
                availableExtenstions.append(ext)
            }
            
            if ext.extensionName == VK_EXT_DEBUG_UTILS_EXTENSION_NAME {
                availableExtenstions.append(ext)
            }
        }
        
        assert(isSurfaceFound, "No surface extension found, is a driver installed?")
        assert(isPlatformExtFound, "No surface extension found, is a driver installed?")
        
        return availableExtenstions
    }
}

#if os(macOS) || os(iOS) || os(tvOS)

import MetalKit

public extension VulkanRenderContext {
    func createWindow(for view: MTKView, size: Vector2i) throws {
        precondition(self.vulkan != nil, "Vulkan instance not created.")
        
        let surface = try Surface(vulkan: self.vulkan!, view: view)
        try self.createWindow(surface: surface, size: size)
    }
}

#endif

extension VulkanRenderContext {
    // TODO: Change to constants
    static var platformSpecificSurfaceExtensionName: String {
        #if os(macOS)
        return "VK_MVK_macos_surface"
        #elseif os(iOS) || os(tvOS)
        return "VK_MVK_ios_surface"
        #elseif os(Windows)
        return "VK_MVK_ios_surface"
        #elseif os(Linux)
        return "VK_MVK_ios_surface"
        #else
        return "NotFound"
        #endif
    }
}

public struct AdaError: LocalizedError {
    let message: String
    
    public init(_ message: String) {
        self.message = message
    }
    
    public var errorDescription: String? {
        return message
    }
}

extension Array {
    subscript(_ index: UInt32) -> Element {
        get {
            return self[Int(index)]
        }
        
        set {
            self[Int(index)] = newValue
        }
    }
}
