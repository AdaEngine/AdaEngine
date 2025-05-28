//
//  MetalFramebuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/29/23.
//

#if METAL
import AdaUtils
import Metal
import Math

final class MetalFramebuffer: Framebuffer {

    private(set) var attachments: [FramebufferAttachment]
    private(set) var renderPassDescriptor: MTLRenderPassDescriptor!
    private(set) var descriptor: FramebufferDescriptor
    
    private var size: SizeInt = .zero
    
    init(descriptor: FramebufferDescriptor) {
        self.descriptor = descriptor
        self.attachments = []

        let size = SizeInt(
            width: descriptor.width,
            height: descriptor.height
        )
        
        self.size = size
        self.invalidate()
    }
    
    func resize(to newSize: SizeInt) {
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
        let renderPassDescriptor = MTLRenderPassDescriptor()
        
        self.attachments.removeAll(keepingCapacity: true)
        
        let size = SizeInt(
            width: Int(Float(self.size.width) * self.descriptor.scale),
            height: Int(Float(self.size.height) * self.descriptor.scale)
        )
        
        for (index, attachmentDesc) in self.descriptor.attachments.enumerated() {
            let framebufferAttachment: FramebufferAttachment
            
            let texture = attachmentDesc.texture ?? RenderTexture(
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
        
        renderPassDescriptor.renderTargetWidth = size.width
        renderPassDescriptor.renderTargetHeight = size.height
        
        self.renderPassDescriptor = renderPassDescriptor
    }
}

#endif
