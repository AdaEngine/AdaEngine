//
//  MetalSampler.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/22/23.
//

#if canImport(WebGPU)
import WebGPU

final class WGPUSampler: Sampler, Sendable {
    
    let descriptor: SamplerDescriptor
    let wgpuSampler: WebGPU.Sampler
    
    init(descriptor: SamplerDescriptor, wgpuSampler: WebGPU.Sampler) {
        self.descriptor = descriptor
        self.wgpuSampler = wgpuSampler
    }
}

extension SamplerMinMagFilter {
    var toWebGPU: WebGPU.FilterMode {
        switch self {
        case .nearest: return .nearest
        case .linear: return .linear
        }
    }
}

extension SamplerMipFilter {
    var toWebGPU: WebGPU.MipmapFilterMode {
        switch self {
        case .nearest: return .nearest
        case .linear: return .linear
        case .notMipmapped: return .undefined
        }
    }
}

#endif
