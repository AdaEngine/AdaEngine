//
//  MetalSampler.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/22/23.
//

#if canImport(WebGPU)
@unsafe @preconcurrency import Metal

final class WGPUSampler: Sampler, Sendable {
    
    let descriptor: SamplerDescriptor
    let mtlSampler: MTLSamplerState
    
    init(descriptor: SamplerDescriptor, mtlSampler: MTLSamplerState) {
        self.descriptor = descriptor
        self.mtlSampler = mtlSampler
    }
}

#endif
