//
//  File.swift
//  
//
//  Created by v.prusakov on 9/24/21.
//

import CVulkan
import Vulkan
import Foundation
import Math
import CSDL2

struct VkQueueFamilyIndices {
    var graphicsFamily: UInt32?
    var presentFamily: UInt32?
    
    func isComplete() -> Bool {
        return graphicsFamily != nil && presentFamily != nil
    }
}

let MAX_FRAMES_IN_FLIGHT = 2

var deviceExtensions = [(VK_KHR_SWAPCHAIN_EXTENSION_NAME as NSString).utf8String]
var validationLayers = [("VK_LAYER_KHRONOS_validation" as NSString).utf8String]

public class VulkanTriangle {
    
    var instance: VulkanInstance!
    var surface: Surface!
    
    var graphicsQueue: Queue!
    var presentQueue: Queue!
    
    var swapchain: Swapchain!
    var device: Device!
    var physicalDevice: PhysicalDevice!
    var swapChainImages: [VkImage] = []
    
    var swapChainImageFormat: VkFormat!
    var swapChainExtent: VkExtent2D!
    var swapChainImageViews: [ImageView] = []
    var swapChainFramebuffers = [Framebuffer]()
    
    var renderPass: RenderPass!
    var pipelineLayout: PipelineLayout!
    var graphicsPipeline: RenderPipeline!
    
    var commandPool: CommandPool!
    var commandBuffers: [CommandBuffer] = []
    
    var imageAvailableSemaphores: [Vulkan.Semaphore] = []
    var renderFinishedSemaphores: [Vulkan.Semaphore] = []
    
    var inFlightFences: [Fence] = []
    var imagesInFlight: [Fence?] = []
    
    var currentFrame: Int = 0
    
    // MARK: - Public
    
    public init() {} 
    
    public func run(on view: RenderView) throws {
        let size = view.frame.size
        
        try self.initVulkan(view: view, size: Vector2i(Int(size.width), Int(size.height)))
    }
    
    public func drawFrame() throws {
        let fence = self.inFlightFences[self.currentFrame]
        
        var imageIndex: UInt32 = 0
        vkAcquireNextImageKHR(self.device.rawPointer, self.swapchain.rawPointer, .max, imageAvailableSemaphores[currentFrame].rawPointer, fence.rawPointer, &imageIndex)
        
        if imagesInFlight.indices.contains(Int(imageIndex)) {
            try imagesInFlight[imageIndex]?.wait()
        }
        
        imagesInFlight[imageIndex] = inFlightFences[currentFrame]
        
        var waitSemaphores: [VkSemaphore?] = [imageAvailableSemaphores[currentFrame].rawPointer]
        var signalSemaphores: [VkSemaphore?] = [imageAvailableSemaphores[currentFrame].rawPointer]
        var commandBuffers: [VkCommandBuffer?] = [self.commandBuffers[imageIndex].rawPointer]
        var stages = [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue]
        
        var submitInfo = VkSubmitInfo(
            sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
            pNext: nil,
            waitSemaphoreCount: 1,
            pWaitSemaphores: &waitSemaphores,
            pWaitDstStageMask: &stages,
            commandBufferCount: 1,
            pCommandBuffers: &commandBuffers,
            signalSemaphoreCount: 1,
            pSignalSemaphores: &signalSemaphores
        )
        
        try inFlightFences[currentFrame].reset()
        
        let result = vkQueueSubmit(self.graphicsQueue.rawPointer, 1, &submitInfo, inFlightFences[currentFrame].rawPointer)
        try vkCheck(result)
        var swapchains: [VkSwapchainKHR?] = [self.swapchain.rawPointer]
        
        var presentInfo = VkPresentInfoKHR(
            sType: VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            pNext: nil,
            waitSemaphoreCount: 1,
            pWaitSemaphores: &waitSemaphores,
            swapchainCount: 1,
            pSwapchains: &swapchains,
            pImageIndices: &imageIndex,
            pResults: nil
        )
        
        let presentResult = vkQueuePresentKHR(self.presentQueue.rawPointer, &presentInfo)
        try vkCheck(presentResult)
        
        self.currentFrame = (currentFrame + 1) % MAX_FRAMES_IN_FLIGHT
    }
    
    // MARK: - Private
    
    private func initVulkan(view: RenderView, size: Vector2i) throws {
        try self.createInstance()
        try self.createSurface(renderView: view)
        try self.pickPhysicalDevice()
        try self.createLogicalDevice()
        try self.createSwapChain()
        try self.createImageViews()
        try self.createRenderPass()
        try self.createGraphicsPipeline()
        try self.createFramebuffers()
        try self.createCommandPool()
        try self.createCommandBuffers()
        try self.createSyncObjects()
    }
    
    private func createInstance() throws {
        
        let version = Self.determineVulkanVersion()
        
        let appInfo = VkApplicationInfo(
            sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
            pNext: nil,
            pApplicationName: "Hello Triangle",
            applicationVersion: vkMakeApiVersion(1, 0, 0),
            pEngineName: "AdaEngine",
            engineVersion: vkMakeApiVersion(0, 0, 1),
            apiVersion: version
        )
        
        let extensions = try Self.provideExtensions()
        let info = InstanceCreateInfo(
            applicationInfo: appInfo,
            // TODO: Add enabledLayers flag to manage layers
            enabledLayerNames: ["VK_LAYER_KHRONOS_validation"],
            enabledExtensionNames: extensions
        )
        
        self.instance = try VulkanInstance(info: info)
    }
    
    private func createSurface(renderView: RenderView) throws {
        let surface = try Surface(vulkan: self.instance, view: renderView)
        self.surface = surface
    }
    
    private func pickPhysicalDevice() throws {
        let devices = try self.instance.physicalDevices()
        
        for device in devices where try self.isDeviceSuitable(device) {
            self.physicalDevice = device
            break
        }
        
        if self.physicalDevice == nil {
            throw NSError()
        }
    }
    
    private func isDeviceSuitable(_ device: PhysicalDevice) throws -> Bool {
        let indicies = try self.findQueueFamilies(for: device)
        
        return indicies.isComplete()
    }
    
    private func findQueueFamilies(for device: PhysicalDevice) throws -> VkQueueFamilyIndices {
        let queueFamilies = device.getQueueFamily()
        
        var indicies = VkQueueFamilyIndices()
        
        for queueFamily in queueFamilies {
            if (queueFamily.queueFlags.contains(.graphicsBit)) {
                indicies.graphicsFamily = queueFamily.index
            }
            
            let support = try device.supportSurface(self.surface, queueFamily: queueFamily)
            
            if support {
                indicies.presentFamily = queueFamily.index
            }
            
            if indicies.isComplete() {
                break
            }
        }
        
        return indicies
    }
    
    private func createLogicalDevice() throws {
        let indecies = try self.findQueueFamilies(for: self.physicalDevice)
        
        var createInfos = [VkDeviceQueueCreateInfo]()
        let uniqueQueueFamilies = [indecies.graphicsFamily, indecies.presentFamily].flatMap { $0 }
        
        var queuePriority: Float = 1
        for queueFamily in uniqueQueueFamilies {
            let createInfo = VkDeviceQueueCreateInfo(
                sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                queueFamilyIndex: queueFamily,
                queueCount: 1,
                pQueuePriorities: &queuePriority
            )
            
            createInfos.append(createInfo)
        }
        
        var deviceFeatures = VkPhysicalDeviceFeatures()
        
        let createInfo = VkDeviceCreateInfo(
            sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            queueCreateInfoCount: UInt32(createInfos.count),
            pQueueCreateInfos: &createInfos,
            enabledLayerCount: 1,
            ppEnabledLayerNames: &validationLayers,
            enabledExtensionCount: 1,
            ppEnabledExtensionNames: &deviceExtensions,
            pEnabledFeatures: &deviceFeatures
        )
        
        self.device = try Device(physicalDevice: self.physicalDevice, createInfo: createInfo)
        
        self.presentQueue = self.device.getQueue(at: Int(indecies.presentFamily!))
        self.graphicsQueue = self.device.getQueue(at: Int(indecies.graphicsFamily!))
    }
    
    private func createSwapChain() throws {
        let swapChainSupport = self.querySwapChainSupport(self.device)
        
        let surfaceFormat = chooseSwapSurfaceFormat(formats: swapChainSupport.formats)
        let presentMode = chooseSwapPresentMode(modes: swapChainSupport.presentModes)
        let extent = chooseSwapExtent(capabilities: swapChainSupport.capabilities)
        
        var imageCount = swapChainSupport.capabilities.minImageCount + 1
        
        if swapChainSupport.capabilities.maxImageCount > 0 && imageCount > swapChainSupport.capabilities.maxImageCount {
            imageCount = swapChainSupport.capabilities.maxImageCount
        }
        
        let indices = try findQueueFamilies(for: self.physicalDevice)
        let queueFamilyIndices = [indices.graphicsFamily!, indices.presentFamily!]
        
        var imageSharingMode: VkSharingMode
        var queueFamilyIndexCount: UInt32 = 0
        
        if indices.graphicsFamily != indices.presentFamily {
            queueFamilyIndexCount = 2
            imageSharingMode = VK_SHARING_MODE_CONCURRENT
        } else {
            imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
        }
        
        let createInfo = VkSwapchainCreateInfoKHR(
            sType: VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            pNext: nil,
            flags: 0,
            surface: self.surface.rawPointer,
            minImageCount: imageCount,
            imageFormat: surfaceFormat.format,
            imageColorSpace: surfaceFormat.colorSpace,
            imageExtent: extent,
            imageArrayLayers: 1,
            imageUsage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue,
            imageSharingMode: imageSharingMode,
            queueFamilyIndexCount: queueFamilyIndexCount,
            pQueueFamilyIndices: queueFamilyIndexCount > 0 ? queueFamilyIndices : nil,
            preTransform: swapChainSupport.capabilities.currentTransform,
            compositeAlpha: VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            presentMode: presentMode,
            clipped: true,
            oldSwapchain: nil
        )
        
        self.swapchain = try Swapchain(device: self.device, createInfo: createInfo)
        
        self.swapChainImages = try self.swapchain.getImages()
        self.swapChainImageFormat = surfaceFormat.format
        self.swapChainExtent = extent
    }
    
    private func createImageViews() throws {
        for image in self.swapChainImages {
            let info = VkImageViewCreateInfo(
                sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                pNext: nil,
                flags: 0,
                image: image,
                viewType: VK_IMAGE_VIEW_TYPE_2D,
                format: swapChainImageFormat,
                components: VkComponentMapping(r: VK_COMPONENT_SWIZZLE_IDENTITY, g: VK_COMPONENT_SWIZZLE_IDENTITY, b: VK_COMPONENT_SWIZZLE_IDENTITY, a: VK_COMPONENT_SWIZZLE_IDENTITY),
                subresourceRange: VkImageSubresourceRange(aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue, baseMipLevel: 0, levelCount: 1, baseArrayLayer: 0, layerCount: 1)
            )
            
            let imageView = try ImageView(device: self.device, info: info)
            self.swapChainImageViews.append(imageView)
        }
    }
    
    private func createRenderPass() throws {
        var colorAttachment = VkAttachmentDescription(
            flags: 0,
            format: swapChainImageFormat,
            samples: VK_SAMPLE_COUNT_1_BIT,
            loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
            storeOp: VK_ATTACHMENT_STORE_OP_STORE,
            stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
            finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        )
        
        var colorAttachmentRef = VkAttachmentReference(
            attachment: 0,
            layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        )
        
        var subpass = VkSubpassDescription(
            flags: 0,
            pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
            inputAttachmentCount: 0,
            pInputAttachments: nil,
            colorAttachmentCount: 1,
            pColorAttachments: &colorAttachmentRef,
            pResolveAttachments: nil,
            pDepthStencilAttachment: nil,
            preserveAttachmentCount: 0,
            pPreserveAttachments: nil
        )
        
        var dependency = VkSubpassDependency(
            srcSubpass: VK_SUBPASS_EXTERNAL,
            dstSubpass: 0,
            srcStageMask: VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue,
            dstStageMask: VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT.rawValue,
            srcAccessMask: 0,
            dstAccessMask: VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT.rawValue,
            dependencyFlags: 0
        )
        
        let renderPassInfo = VkRenderPassCreateInfo(
            sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            pNext: nil,
            flags: 0,
            attachmentCount: 1,
            pAttachments: &colorAttachment,
            subpassCount: 1,
            pSubpasses: &subpass,
            dependencyCount: 1,
            pDependencies: &dependency
        )
        
        self.renderPass = try RenderPass(device: self.device, createInfo: renderPassInfo)
        
    }
    
    private func createGraphicsPipeline() throws {
        let frag = try! Data(contentsOf: Bundle.module.url(forResource: "shader.frag", withExtension: "spv")!)
        let vert = try! Data(contentsOf: Bundle.module.url(forResource: "shader.vert", withExtension: "spv")!)
        let vertModule = try ShaderModule(device: self.device, shaderData: vert)
        let fragModule = try ShaderModule(device: self.device, shaderData: frag)
        
        var vertShaderStageInfo = VkPipelineShaderStageCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stage: VK_SHADER_STAGE_VERTEX_BIT,
            module: vertModule.rawPointer,
            pName: ("main" as NSString).utf8String,
            pSpecializationInfo: nil
        )
        
        var fragShaderStageInfo = VkPipelineShaderStageCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stage: VK_SHADER_STAGE_FRAGMENT_BIT,
            module: fragModule.rawPointer,
            pName: ("main" as NSString).utf8String,
            pSpecializationInfo: nil
        )
        
        var shaderStages = [vertShaderStageInfo, fragShaderStageInfo]
        
        var vertexInputInfo = VkPipelineVertexInputStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            vertexBindingDescriptionCount: 0,
            pVertexBindingDescriptions: nil,
            vertexAttributeDescriptionCount: 0,
            pVertexAttributeDescriptions: nil
        )
        
        var inputAssembly = VkPipelineInputAssemblyStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            primitiveRestartEnable: false
        )
        
        var viewport = VkViewport(
            x: 0,
            y: 0,
            width: Float(swapChainExtent.width),
            height: Float(swapChainExtent.height),
            minDepth: 0,
            maxDepth: 1
        )
        
        var scissor = VkRect2D(offset: VkOffset2D(x: 0, y: 0), extent: swapChainExtent)
        
        var viewportState = VkPipelineViewportStateCreateInfo(
            sType: VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            viewportCount: 1,
            pViewports: &viewport,
            scissorCount: 1,
            pScissors: &scissor
        )
        
        var rasterizer = VkPipelineRasterizationStateCreateInfo()
        rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
        rasterizer.depthClampEnable = false
        rasterizer.rasterizerDiscardEnable = false
        rasterizer.polygonMode = VK_POLYGON_MODE_FILL
        rasterizer.lineWidth = 1.0
        rasterizer.cullMode = VK_CULL_MODE_BACK_BIT.rawValue
        rasterizer.frontFace = VK_FRONT_FACE_CLOCKWISE
        rasterizer.depthBiasEnable = false
        
        var multisampling = VkPipelineMultisampleStateCreateInfo()
        multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
        multisampling.sampleShadingEnable = false
        multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT
        
        var colorBlendAttachment = VkPipelineColorBlendAttachmentState()
        colorBlendAttachment.colorWriteMask = VK_COLOR_COMPONENT_R_BIT.rawValue | VK_COLOR_COMPONENT_G_BIT.rawValue | VK_COLOR_COMPONENT_B_BIT.rawValue | VK_COLOR_COMPONENT_A_BIT.rawValue
        colorBlendAttachment.blendEnable = false
        
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
        
        var pipelineLayoutInfo = VkPipelineLayoutCreateInfo()
        pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
        pipelineLayoutInfo.setLayoutCount = 0
        pipelineLayoutInfo.pushConstantRangeCount = 0
        
        self.pipelineLayout = try PipelineLayout(device: device, createInfo: pipelineLayoutInfo)
        
        let pipelineInfo = VkGraphicsPipelineCreateInfo(
            sType: VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            stageCount: 2,
            pStages: &shaderStages,
            pVertexInputState: &vertexInputInfo,
            pInputAssemblyState: &inputAssembly,
            pTessellationState: nil,
            pViewportState: &viewportState,
            pRasterizationState: &rasterizer,
            pMultisampleState: &multisampling,
            pDepthStencilState: nil,
            pColorBlendState: &colorBlending,
            pDynamicState: nil,
            layout: self.pipelineLayout.rawPointer,
            renderPass: self.renderPass.rawPointer,
            subpass: 0,
            basePipelineHandle: nil,
            basePipelineIndex: 0
        )
        
        self.graphicsPipeline = try RenderPipeline(device: self.device, pipelineLayout: self.pipelineLayout, graphicCreateInfo: pipelineInfo)
    }
    
    private func createFramebuffers() throws {
        for imageView in self.swapChainImageViews {
            
            var attachment = imageView.rawPointer
            
            let framebufferInfo = VkFramebufferCreateInfo(
                sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                pNext: nil,
                flags: 0,
                renderPass: self.renderPass.rawPointer,
                attachmentCount: 1,
                pAttachments: &attachment,
                width: swapChainExtent.width,
                height: swapChainExtent.height,
                layers: 1
            )
            
            let framebuffer = try Framebuffer(device: self.device, createInfo: framebufferInfo)
            self.swapChainFramebuffers.append(framebuffer)
        }
    }
    
    private func createCommandPool() throws {
        let queueFamilyIndices = try self.findQueueFamilies(for: self.physicalDevice)
        
        self.commandPool = try CommandPool(device: self.device, queueFamilyIndex: queueFamilyIndices.graphicsFamily!)
    }
    
    private func createCommandBuffers() throws {
        
        var allocInfo = VkCommandBufferAllocateInfo(
            sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            pNext: nil,
            commandPool: self.commandPool.rawPointer,
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: UInt32(self.swapChainImageViews.count)
        )
        
        var commandBuffersArray = [VkCommandBuffer?].init(repeating: nil, count: self.swapChainImageViews.count)
        vkAllocateCommandBuffers(self.device.rawPointer, &allocInfo, &commandBuffersArray)
        
        let commandBuffers: [CommandBuffer] = commandBuffersArray.compactMap { ptr in
            guard let ptr = ptr else { return nil }
            return CommandBuffer(device: self.device, commandPool: self.commandPool, pointer: ptr)
        }
        
        for index in 0..<commandBuffers.count {
            
            let commandBuffer = commandBuffers[index]
            
            try commandBuffer.beginUpdate()
            
            var clearValue = VkClearValue(color: VkClearColorValue(float32: (0, 0, 0, 1)))
            
            var renderPassInfo = VkRenderPassBeginInfo(
                sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
                pNext: nil,
                renderPass: self.renderPass.rawPointer,
                framebuffer: self.swapChainFramebuffers[index].rawPointer,
                renderArea: VkRect2D(offset: VkOffset2D(x: 0, y: 0), extent: swapChainExtent),
                clearValueCount: 1,
                pClearValues: &clearValue
            )
            
            vkCmdBeginRenderPass(commandBuffer.rawPointer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE)
            
                vkCmdBindPipeline(commandBuffer.rawPointer, VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicsPipeline.rawPointer)
            
                vkCmdDraw(commandBuffer.rawPointer, 3, 1, 0, 0)
            
            vkCmdEndRenderPass(commandBuffer.rawPointer)
            
            try commandBuffer.endUpdate()
        }
        
        self.commandBuffers = commandBuffers
    }
    
    private func createSyncObjects() throws {
        imagesInFlight = [Fence?].init(repeating: nil, count: self.swapChainImages.count)
        for _ in 0..<MAX_FRAMES_IN_FLIGHT {
            self.imageAvailableSemaphores.append(try Vulkan.Semaphore(device: self.device))
            self.renderFinishedSemaphores.append(try Vulkan.Semaphore(device: self.device))
            self.inFlightFences.append(try Fence(device: self.device))
        }
    }
    
    // MARK: - Statics
    
    private static func determineVulkanVersion() -> UInt32 {
        var version: UInt32 = UInt32.max
        let result = vkEnumerateInstanceVersion(&version)
        
        if result != VK_SUCCESS {
            fatalError("Vulkan API got error when trying get sdk version")
        }
        
        return version
    }
    
    private static func provideExtensions() throws -> [String] {
        let extensions = try VulkanInstance.getExtensions()
        
        var availableExtenstions = [String]()
        var isSurfaceFound = false
        var isPlatformExtFound = false
        
        for ext in extensions {
            if ext.extensionName == VK_KHR_SURFACE_EXTENSION_NAME {
                isSurfaceFound = true
                availableExtenstions.append(ext.extensionName)
            }
            
            if ext.extensionName == "VK_MVK_macos_surface" {
                availableExtenstions.append(ext.extensionName)
                isPlatformExtFound = true
            }
            
            if ext.extensionName == VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME {
                availableExtenstions.append(ext.extensionName)
            }
            
            if ext.extensionName == VK_EXT_DEBUG_UTILS_EXTENSION_NAME {
                availableExtenstions.append(ext.extensionName)
            }
        }
        
        assert(isSurfaceFound, "No surface extension found, is a driver installed?")
        assert(isPlatformExtFound, "No surface extension found, is a driver installed?")
        
        return availableExtenstions
    }
    
    private func querySwapChainSupport(_ device: Device) -> SwapChainSupportDetails {
        var capabilities: VkSurfaceCapabilitiesKHR = VkSurfaceCapabilitiesKHR()
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.physicalDevice.pointer, self.surface.rawPointer, &capabilities)
        
        var formatsCount: UInt32 = 0
        vkGetPhysicalDeviceSurfaceFormatsKHR(self.physicalDevice.pointer, self.surface.rawPointer, &formatsCount, nil)
        
        var formats = [VkSurfaceFormatKHR].init(repeating: VkSurfaceFormatKHR(), count: Int(formatsCount))
        vkGetPhysicalDeviceSurfaceFormatsKHR(self.physicalDevice.pointer, self.surface.rawPointer, &formatsCount, &formats)
        
        var presentModeCount: UInt32 = 0
        vkGetPhysicalDeviceSurfacePresentModesKHR(self.physicalDevice.pointer, self.surface.rawPointer, &presentModeCount, nil)
        
        var presentModes = [VkPresentModeKHR].init(repeating: VkPresentModeKHR(0), count: Int(presentModeCount))
        vkGetPhysicalDeviceSurfacePresentModesKHR(self.physicalDevice.pointer, self.surface.rawPointer, &presentModeCount, &presentModes)
        
        return SwapChainSupportDetails(capabilities: capabilities, formats: formats, presentModes: presentModes)
    }
    
    private func chooseSwapSurfaceFormat(formats: [VkSurfaceFormatKHR]) -> VkSurfaceFormatKHR {
        for format in formats {
            if format.format == VK_FORMAT_B8G8R8A8_SRGB && format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR {
                return format
            }
        }
        
        return formats[0]
    }
    
    private func chooseSwapPresentMode(modes: [VkPresentModeKHR]) -> VkPresentModeKHR {
        for mode in modes {
            if mode == VK_PRESENT_MODE_MAILBOX_KHR {
                return mode
            }
        }
        
        return VK_PRESENT_MODE_FIFO_KHR
    }
    
    private func chooseSwapExtent(capabilities: VkSurfaceCapabilitiesKHR) -> VkExtent2D {
        if capabilities.currentExtent.width != .max {
            return capabilities.currentExtent
        } else {
            fatalError()
        }
    }
}

struct SwapChainSupportDetails {
    var capabilities: VkSurfaceCapabilitiesKHR
    var formats: [VkSurfaceFormatKHR]
    var presentModes: [VkPresentModeKHR]
}

extension Int {
    var ui32: UInt32 {
        return UInt32(self)
    }
}
