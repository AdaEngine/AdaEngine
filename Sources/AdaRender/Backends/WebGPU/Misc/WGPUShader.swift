//
//  WGPUShader.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if canImport(WebGPU)
import WebGPU
import CWebGPU
import Foundation

final class WGPUShader: CompiledShader {
    let shader: WebGPU.ShaderModule

    init(shader: Shader, device: WebGPU.Device) {
        let shaderData: any WebGPU.Chained = switch shader.source {
        case .code(let code):
            ShaderSourceWgsl(code: code)
        case .spirv(let data):
            // SPIRV binary consists of 32-bit words (UInt32), not bytes
            // We need to read the data as UInt32 array directly
            unsafe data.withUnsafeBytes { pointer in
                let words = unsafe pointer.bindMemory(to: UInt32.self)
                return unsafe ShaderSourceSpirv(code: Array(words))
            }
        }
        let module = device.createShaderModule(
            descriptor: ShaderModuleDescriptor(
                label: shader.entryPoint,
                nextInChain: shaderData
            )
        )

        self.shader = module
    }
}
#endif
