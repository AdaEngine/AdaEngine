//
//  WGPUShader.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
@unsafe @preconcurrency import WebGPU
import Foundation
import AdaUtils

@_spi(Internal)
public final class WGPUShader: CompiledShader {
    public let shader: WebGPU.GPUShaderModule

    init(shader: Shader, device: WebGPU.GPUDevice) {
        let shaderData: any WebGPU.GPUChainedStruct

        switch shader.source {
        case .code(let code):
            shaderData = WebGPU.GPUShaderSourceWGSL(code: code)
        case .spirv:
           fatalError("SPIR-V shaders are not supported for WebGPU")
        }

        let module = device.createShaderModule(
            descriptor: WebGPU.GPUShaderModuleDescriptor(
                label: shader.entryPoint,
                nextInChain: shaderData
            )
        )

        self.shader = module
    }
}
#endif
