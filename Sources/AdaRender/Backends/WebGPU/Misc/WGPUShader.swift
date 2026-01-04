//
//  MetalShader.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
import WebGPU
import CWebGPU

final class WGPUShader: CompiledShader {
    let shader: WebGPU.ShaderModule

    init(shader: WebGPU.ShaderModule) {
        self.shader = shader
    }
}
#endif
