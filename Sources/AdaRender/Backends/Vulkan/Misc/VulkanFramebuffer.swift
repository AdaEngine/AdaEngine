//
//  VulkanFramebuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/18/24.
//

#if VULKAN
import CVulkan
import Vulkan
import Math

final class VulkanFramebuffer: Framebuffer {

    private(set) var attachments: [FramebufferAttachment]
    private(set) var descriptor: FramebufferDescriptor

    private(set) var isScreenBuffer = false
    private var size: SizeInt = .zero

    private unowned let device: Device
    private(set) var vkFramebuffer: Vulkan.Framebuffer!
    private(set) var renderPass: Vulkan.RenderPass!
    
    init(device: Device, framebuffer: Vulkan.Framebuffer, renderPass: Vulkan.RenderPass) {
        self.device = device
        self.vkFramebuffer = framebuffer
        self.renderPass = renderPass
        
        self.isScreenBuffer = true
        
        self.attachments = []
        descriptor = FramebufferDescriptor()
    }

    init(device: Device, descriptor: FramebufferDescriptor) {
        self.device = device
        self.descriptor = descriptor

        self.attachments = []

        self.size = SizeInt(
            width: descriptor.width,
            height: descriptor.height
        )

        self.invalidate()
    }

    func resize(to newSize: Math.SizeInt) {
        guard newSize.width >= 0 && newSize.height >= 0 else {
            return
        }

        if self.size.width == newSize.width && self.size.height == newSize.height {
            return
        }

        self.size = newSize

        self.invalidate()
    }

    func invalidate() {
        let holder = VulkanUtils.TemporaryBufferHolder(label: "Framebuffer")

        self.attachments.removeAll(keepingCapacity: true)

        let size = Size(
            width: Float(self.size.width) * self.descriptor.scale,
            height: Float(self.size.height) * self.descriptor.scale
        )
        
        let desciptor = self.descriptor
        
        var attachmentDescriptors = [VkAttachmentDescription]()
        var colorAttachmentReferences = [VkAttachmentReference]()
        var colorAttachments = [VulkanGPUTexture]()
        
        var depthAttachment: VulkanGPUTexture?
        
        for (index, attachment) in desciptor.attachments.enumerated() {
            if attachment.format.isDepthFormat {
                let description = VkAttachmentDescription(
                    flags: 0,
                    format: attachment.format.toVulkan,
                    samples: VK_SAMPLE_COUNT_1_BIT,
                    loadOp: attachment.loadAction.toVulkan,
                    storeOp: attachment.storeAction.toVulkan,
                    stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                    stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
                    initialLayout: desciptor.depthLoadAction == .load ? VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL : VK_IMAGE_LAYOUT_UNDEFINED,
                    finalLayout: VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL
                )
                
                if let texture = attachment.texture?.gpuTexture as? VulkanGPUTexture {
                    depthAttachment = texture
                }
                
                attachmentDescriptors.append(description)
            } else {
                let description = VkAttachmentDescription(
                    flags: 0,
                    format: attachment.format.toVulkan,
                    samples: VK_SAMPLE_COUNT_1_BIT,
                    loadOp: attachment.loadAction.toVulkan,
                    storeOp: attachment.storeAction.toVulkan,
                    stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                    stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
                    initialLayout: attachment.loadAction == .clear ? VK_IMAGE_LAYOUT_UNDEFINED : VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                    finalLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
                )
                
                attachmentDescriptors.append(description)
                
                if let texture = attachment.texture, let gpuTexture = texture.gpuTexture as? VulkanGPUTexture {
                    colorAttachments.append(gpuTexture)
                } else {
                    
                }
                
                colorAttachmentReferences.append(VkAttachmentReference(
                    attachment: UInt32(index),
                    layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
                )
            }
        }
        
        let attachmentDescriptorsPtr = holder.unsafePointerCopy(collection: attachmentDescriptors)
        
        let pColorAttachmentReferences = holder.unsafePointerCopy(collection: colorAttachmentReferences)
        
        let subpassDescription = VkSubpassDescription(
            flags: 0,
            pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
            inputAttachmentCount: 0,
            pInputAttachments: nil,
            colorAttachmentCount: UInt32(colorAttachmentReferences.count),
            pColorAttachments: pColorAttachmentReferences,
            pResolveAttachments: nil,
            pDepthStencilAttachment: nil, //UnsafePointer<VkAttachmentReference>!,
            preserveAttachmentCount: 0,
            pPreserveAttachments: nil
        )
        
        let pSubpasses = holder.unsafePointerCopy(from: subpassDescription)
        
//        var dependencies = [VkSubpassDependency]()
        
        let renderPassCreateInfo = VkRenderPassCreateInfo(
            sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            pNext: nil,
            flags: 0,
            attachmentCount: UInt32(desciptor.attachments.count),
            pAttachments: attachmentDescriptorsPtr,
            subpassCount: 1,
            pSubpasses: pSubpasses,
            dependencyCount: UInt32(0),
            pDependencies: nil//UnsafePointer<VkSubpassDependency>!
        )
        
        do {
            let renderPass = try Vulkan.RenderPass(device: device, createInfo: renderPassCreateInfo)
            
            var attachments: [VkImageView?] = colorAttachments.map { $0.imageView.rawPointer }
            
            if let attachment = depthAttachment {
                attachments.append(attachment.imageView.rawPointer)
            }
            
            let pAttachments = holder.unsafePointerCopy(collection: attachments)
            
            let createInfo = VkFramebufferCreateInfo(
                sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                pNext: nil,
                flags: 0,
                renderPass: renderPass.rawPointer,
                attachmentCount: UInt32(attachments.count),
                pAttachments: pAttachments,
                width: UInt32(size.width),
                height: UInt32(size.height),
                layers: 1
            )

            self.vkFramebuffer = try Vulkan.Framebuffer(device: device, createInfo: createInfo)
            self.renderPass = renderPass
        } catch {
            assertionFailure("Failed to invalidate framebuffer")
        }
    }
}

extension AttachmentLoadAction {
    var toVulkan: VkAttachmentLoadOp {
        switch self {
        case .clear:
            return VK_ATTACHMENT_LOAD_OP_CLEAR
        case .load:
            return VK_ATTACHMENT_LOAD_OP_LOAD
        case .dontCare:
            return VK_ATTACHMENT_LOAD_OP_DONT_CARE
        }
    }
}

extension AttachmentStoreAction {
    var toVulkan: VkAttachmentStoreOp {
        switch self {
        case .store:
            return VK_ATTACHMENT_STORE_OP_STORE
        case .dontCare:
            return VK_ATTACHMENT_STORE_OP_DONT_CARE
        }
    }
}

#endif
