//
//  VulkanGPUTexture.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/11/24.
//

#if VULKAN
import CVulkan
import Vulkan

class VulkanGPUTexture: GPUTexture {

    let image: Vulkan.Image
    let imageView: Vulkan.ImageView

    init(device: Device, descriptor: TextureDescriptor) throws {
        var imageInfo = VkImageCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            imageType: VK_IMAGE_TYPE_2D,
            format: descriptor.pixelFormat.toVulkan,
            extent: VkExtent3D(width: UInt32(descriptor.width), height: UInt32(descriptor.height), depth: 1),
            mipLevels: UInt32(descriptor.mipmapLevel),
            arrayLayers: 1,
            samples: VK_SAMPLE_COUNT_1_BIT,
            tiling: VK_IMAGE_TILING_OPTIMAL,
            usage: VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
        )

        if descriptor.textureType == .textureCube {
            imageInfo.flags |= VK_IMAGE_CREATE_CUBE_COMPATIBLE_BIT.rawValue
        }

        let vkImage = try Vulkan.Image(
            device: device,
            createInfo: imageInfo
        )

        let imageViewInfo = VkImageViewCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            pNext: nil,
            flags: 0,
            image: vkImage.rawPointer,
            viewType: descriptor.textureType.toVulkan,
            format: descriptor.pixelFormat.toVulkan,
            components: VkComponentMapping(
                r: VK_COMPONENT_SWIZZLE_IDENTITY,
                g: VK_COMPONENT_SWIZZLE_IDENTITY,
                b: VK_COMPONENT_SWIZZLE_IDENTITY,
                a: VK_COMPONENT_SWIZZLE_IDENTITY
            ),
            subresourceRange: VkImageSubresourceRange(
                aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                baseMipLevel: 0,
                levelCount: imageInfo.mipLevels,
                baseArrayLayer: 0,
                layerCount: imageInfo.arrayLayers
            )
        )

        let imageView = try Vulkan.ImageView(device: device, info: imageViewInfo)

        self.image = vkImage
        self.imageView = imageView
    }
}

#endif
