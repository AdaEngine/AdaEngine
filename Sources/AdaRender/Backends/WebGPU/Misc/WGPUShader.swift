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

@_spi(Internal)
public final class WGPUShader: CompiledShader {
    public let shader: WebGPU.ShaderModule

    init(shader: Shader, device: WebGPU.Device) {
        let shaderData: any WebGPU.Chained

        switch shader.source {
        case .code(let code):
            print("[WebGPU] Creating shader from WGSL code, entryPoint: \(shader.entryPoint)")
            shaderData = ShaderSourceWgsl(code: code)
        case .spirv(let data):
            // SPIRV binary consists of 32-bit words (UInt32), not bytes
            // We need to read the data as UInt32 array directly
            shaderData = unsafe data.withUnsafeBytes { pointer in
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
        
        // Check for compilation errors
        module.getCompilationInfo { result in
            switch result {
            case .success(let compilationInfo):
                for message in compilationInfo.messages {
                    print("[WebGPU] Shader message [\(message.type)]: \(message.message) at line \(message.lineNum)")
                }
            case .failure(let error):
                print("[WebGPU] Shader compilation failed: \(error)")
            }
        }

        self.shader = module
    }
}
#endif
