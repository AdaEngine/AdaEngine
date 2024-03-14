//
//  VulkanGPUTexture.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/11/24.
//

#if VULKAN
import Vulkan

class VulkanGPUTexture: GPUTexture {
    let image: Vulkan.Image
    let imageView: Vulkan.ImageView

    init(image: Vulkan.Image, imageView: Vulkan.ImageView) {
        self.image = image
        self.imageView = imageView
    }
}

#endif
