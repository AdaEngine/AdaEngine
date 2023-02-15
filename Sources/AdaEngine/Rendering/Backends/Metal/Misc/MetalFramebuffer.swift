//
//  MetalFramebuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/29/23.
//
#if METAL

import Metal

class MetalFramebuffer: Framebuffer {
    
    private(set) var attachments: [FramebufferAttachment]
    private(set) var renderPassDescriptor: MTLRenderPassDescriptor!
    private(set) var descriptor: FramebufferDescriptor
    
    private var size: Size = .zero
    
    init(descriptor: FramebufferDescriptor) {
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
    
    func resize(to newSize: Size) {
        guard newSize.width >= 0 && newSize.height >= 0 else {
            return
        }
        
        if self.size.width == newSize.width && self.size.height == newSize.height {
            return
        }
        
        self.invalidate()
    }
    
    func invalidate() {
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        
        self.attachments.removeAll(keepingCapacity: true)
        
        let size = Size(
            width: Float(self.size.width) * self.descriptor.scale,
            height: Float(self.size.height) * self.descriptor.scale
        )
        
        for (index, attachmentDesc) in self.descriptor.attachments.enumerated() {
            
            let framebufferAttachment: FramebufferAttachment
            
            let texture = RenderTexture(
                size: size,
                scaleFactor: self.descriptor.scale,
                format: attachmentDesc.format
            )
            
            var usage: FramebufferAttachmentUsage = []
            
            if attachmentDesc.format.isDepthFormat {
                usage.insert(.depthStencilAttachment)
            } else {
                usage.insert(.colorAttachment)
            }
            
            framebufferAttachment = FramebufferAttachment(
                texture: texture,
                usage: usage
            )
            
            if attachmentDesc.format.isDepthFormat {
                renderPassDescriptor.depthAttachment.loadAction = descriptor.depthLoadAction.toMetal
                renderPassDescriptor.depthAttachment.clearDepth = descriptor.clearDepth
                
                if let renderTarget = framebufferAttachment.texture?.gpuTexture as? MetalGPUTexture {
                    renderPassDescriptor.depthAttachment.texture = renderTarget.texture
                    renderPassDescriptor.stencilAttachment.texture = renderTarget.texture
                }
            } else {
                renderPassDescriptor.colorAttachments[index].slice = attachmentDesc.slice
                renderPassDescriptor.colorAttachments[index].clearColor = attachmentDesc.clearColor.toMetalClearColor
                renderPassDescriptor.colorAttachments[index].loadAction = attachmentDesc.loadAction.toMetal
                renderPassDescriptor.colorAttachments[index].storeAction = attachmentDesc.storeAction.toMetal
                
                if let renderTarget = framebufferAttachment.texture?.gpuTexture as? MetalGPUTexture {
                    renderPassDescriptor.colorAttachments[index].texture = renderTarget.texture
                }
            }
            
            self.attachments.append(framebufferAttachment)
        }
        
        renderPassDescriptor.renderTargetWidth = Int(size.width)
        renderPassDescriptor.renderTargetHeight = Int(size.height)
        
        self.renderPassDescriptor = renderPassDescriptor
    }
}

class MetalGPUTexture: GPUTexture {
    var texture: MTLTexture
    
    init(texture: MTLTexture) {
        self.texture = texture
    }
}

#endif
