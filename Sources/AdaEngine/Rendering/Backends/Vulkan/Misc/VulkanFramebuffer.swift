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

    private var size: Size = .zero

    private unowned let device: Device
    private(set) var vkFramebuffer: VkFramebuffer!

    init(device: Device, descriptor: FramebufferDescriptor) {
        self.device = device
        self.descriptor = descriptor

        self.attachments = []

        var size = Size(width: 1, height: 1)

        if descriptor.width == 0 && descriptor.height == 0 {
            let windowSize = Application.shared.windowManager.activeWindow?.frame.size ?? .zero
            if windowSize.height > 0 && windowSize.width > 0 {
                size = windowSize
            }
        } else {
            size = Size(
                width: Float(descriptor.width),
                height: Float(descriptor.width)
            )
        }

        self.size = size

        self.invalidate()
    }

    deinit {
        vkDestroyFramebuffer(self.device.rawPointer, vkFramebuffer, nil)
    }

    func resize(to newSize: Math.Size) {

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
        if vkFramebuffer != nil {
            vkDestroyFramebuffer(self.device.rawPointer, vkFramebuffer, nil)
        }

        self.attachments.removeAll(keepingCapacity: true)

        let size = Size(
            width: Float(self.size.width) * self.descriptor.scale,
            height: Float(self.size.height) * self.descriptor.scale
        )
        
        let desciptor = self.descriptor
        
        var createInfo = VkFramebufferCreateInfo(
            sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            pNext: nil,
            flags: 0,
            renderPass: nil,
            attachmentCount: UInt32(desciptor.attachments.count),
            pAttachments: nil,
            width: UInt32(size.width),
            height: UInt32(size.height),
            layers: 1
        )

        let result = vkCreateFramebuffer(self.device.rawPointer, &createInfo, nil, &vkFramebuffer)
    }
}

#endif
