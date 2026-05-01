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
    public let entryPoint: String

    init(shader: Shader, device: WebGPU.GPUDevice) {
        let shaderData: any WebGPU.GPUChainedStruct
        let entryPoint: String

        switch shader.source {
        case .code(let code):
            shaderData = WebGPU.GPUShaderSourceWGSL(code: code)
            entryPoint = shader.entryPoint
        case .spirv(let data):
            let code = data.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: UInt32.self))
            }
            shaderData = WebGPU.GPUShaderSourceSPIRV(code: code)
            entryPoint = "main"
        }

        let module = device.createShaderModule(
            descriptor: WebGPU.GPUShaderModuleDescriptor(
                label: shader.entryPoint,
                nextInChain: shaderData
            )
        )

        self.shader = module
        self.entryPoint = entryPoint
    }
}
#endif
