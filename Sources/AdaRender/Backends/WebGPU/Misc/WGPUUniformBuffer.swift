//
//  MetalUniformBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/31/23.
//

#if canImport(WebGPU)
import WebGPU

// TODO: (Vlad) think about inheretence and how it affect type casting and vtables
final class WGPUUniformBuffer: WGPUBuffer, UniformBuffer, @unchecked Sendable {

    let binding: Int
    
    init(buffer: WebGPU.Buffer, binding: Int) {
        self.binding = binding
        super.init(buffer: buffer)
    }
}

#endif
