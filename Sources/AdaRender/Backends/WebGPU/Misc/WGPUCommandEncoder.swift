//
//  MetalCommandEncoder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 23.11.2025.
//

#if canImport(WebGPU)
import AdaUtils
import Math
import WebGPU

final class WGPUCommandEncoder: CommandBuffer {
    let device: WebGPU.Device
    let commandEncoder: WebGPU.CommandEncoder

    init(
        device: WebGPU.Device
    ) {
        self.device = device
        self.commandEncoder = device.createCommandEncoder()
    }

    func commit() {
        let commandBuffer = commandEncoder.finish()
        device.queue.submit(commands: [commandBuffer])
    }

    func beginRenderPass(_ desc: RenderPassDescriptor) -> RenderCommandEncoder {
        var wgpuAttachment: WebGPU.RenderPassDepthStencilAttachment?
        if let depthStencilAttachment = desc.depthStencilAttachment {
            let view = (depthStencilAttachment.texture.gpuTexture as! WGPUGPUTexture).textureView
            wgpuAttachment = WebGPU.RenderPassDepthStencilAttachment(
                view: view, 
                depthLoadOp: depthStencilAttachment.depthOperation?.loadAction.toWebGPU ?? .undefined, 
                depthStoreOp: depthStencilAttachment.depthOperation?.storeAction.toWebGPU ?? .undefined, 
                depthClearValue: 1, 
                depthReadOnly: false, 
                stencilLoadOp: depthStencilAttachment.stencilOperation?.loadAction.toWebGPU ?? .undefined, 
                stencilStoreOp: depthStencilAttachment.stencilOperation?.storeAction.toWebGPU ?? .undefined, 
                stencilClearValue: 1, 
                stencilReadOnly: false,
                nextInChain: nil
            )
        }

        let colorAttachments = desc.colorAttachments.map { attachment in
            WebGPU.RenderPassColorAttachment(
                view: (attachment.texture.gpuTexture as! WGPUGPUTexture).textureView, 
                resolveTarget: (attachment.resolveTexture?.gpuTexture as? WGPUGPUTexture)?.textureView,
                loadOp: attachment.operation?.loadAction.toWebGPU ?? .clear, 
                storeOp: attachment.operation?.storeAction.toWebGPU ?? .store, 
                clearValue: attachment.clearColor?.toWebGPU ?? AdaUtils.Color.black.toWebGPU
            )
        }

        let renderPassDescriptor = WebGPU.RenderPassDescriptor(
            label: desc.label, 
            colorAttachments: colorAttachments,
            depthStencilAttachment: wgpuAttachment
        )

        let renderPassEncoder = commandEncoder.beginRenderPass(
            descriptor: renderPassDescriptor
        )
        return WGPURenderCommandEncoder(renderEncoder: renderPassEncoder, device: device)
    }

    func beginBlitPass(_ desc: BlitPassDescriptor) -> BlitCommandEncoder {
        fatalError()
        // guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
        //     fatalError("Failed to create MTLBlitCommandEncoder")
        // }
        // encoder.label = desc.label
        // return MetalBlitCommandEncoder(blitEncoder: encoder)
    }
}

extension AttachmentLoadAction {
    var toWebGPU: WebGPU.LoadOp {
        switch self {
        case .load: return .load
        case .clear: return .clear
        case .dontCare: return .undefined
        }
    }
}

extension AttachmentStoreAction {
    var toWebGPU: WebGPU.StoreOp {
        switch self {
        case .store: return .store
        case .dontCare: return .discard
        }
    }
}

extension AdaUtils.Color {
    var toWebGPU: WebGPU.Color {
        return WebGPU.Color(r: Double(red), g: Double(green), b: Double(blue), a: Double(alpha))
    }
}

#endif
