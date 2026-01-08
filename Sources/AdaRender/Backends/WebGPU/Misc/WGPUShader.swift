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
            print("[WebGPU] Creating shader from SPIRV binary, entryPoint: \(shader.entryPoint), size: \(data.count) bytes")
            
            // Ensure we have the right size (multiple of 4 bytes)
            if data.count % 4 != 0 {
                assertionFailure("[WebGPU] SPIRV data size (\(data.count)) is not a multiple of 4 bytes")
            }
            
            // Bind memory to UInt32 array and create proper array copy
            shaderData = unsafe data.withUnsafeBytes { rawBufferPointer in
                let words = rawBufferPointer.bindMemory(to: UInt32.self)
                let wordCount = data.count / 4
                
                // Create a proper array copy from the buffer
                var spirvArray = [UInt32]()
                spirvArray.reserveCapacity(wordCount)
                for i in 0..<wordCount {
                    unsafe spirvArray.append(words[i])
                }
                
                print("[WebGPU] SPIRV array created with \(spirvArray.count) words (first word: 0x\(String(spirvArray[0], radix: 16)))")
                return ShaderSourceSpirv(code: spirvArray)
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
