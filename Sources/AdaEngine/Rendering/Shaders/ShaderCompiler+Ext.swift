//
//  SpirvCompiler+Ext.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 10.04.2025.
//

//import glslang

extension ShaderCompiler {
    
    struct SpirvOptions {
        let preamble: UnsafePointer<CChar>?
    }
    
    struct SPVError: LocalizedError {
        let errorDescription: String?
    }
    
    func compileSPVShader(
        source: UnsafePointer<CChar>,
        stage: ShaderStage,
        options: SpirvOptions
    ) throws -> Data {
//        let stages: [ShaderStage: glslang_stage_t] = [
//            .vertex: GLSLANG_STAGE_VERTEX,
//            .fragment: GLSLANG_STAGE_FRAGMENT,
//            .tesselationControl: GLSLANG_STAGE_TESSCONTROL,
//            .tesselationEvaluation: GLSLANG_STAGE_TESSEVALUATION,
//            .compute: GLSLANG_STAGE_COMPUTE
//        ]
//        
//        let clientInputSemanticsVersion: UInt32 = 100
//        let defaultVersion: UInt32 = 100
//        let clientVersion = GLSLANG_TARGET_VULKAN_1_2
//        let targetVersion = GLSLANG_TARGET_SPV_1_5
//        
//        var input = glslang_input_t()
//        input.code = source
//        input.stage = stages[stage]!
//        input.target_language_version = targetVersion
//        input.client_version = clientVersion
//        input.client = GLSLANG_CLIENT_VULKAN
//        input.default_version = Int32(defaultVersion)
////        input.client_input_semantics_version = Int32(clientInputSemanticsVersion)
//        
//        let shader = glslang_shader_create(&input)
//        defer { glslang_shader_delete(shader) }
//        
//        if let preamble = options.preamble {
//            glslang_shader_set_preamble(shader, preamble)
//        }
//        
//        // Preprocess
//        guard glslang_shader_preprocess(shader, &input) == 0 else {
//            let errorLog = glslang_shader_get_info_log(shader)
//            throw SPVError(errorDescription: String(cString: errorLog!))
//        }
//        
//        // Parse
//        guard glslang_shader_parse(shader, &input) == 0 else {
//            let errorLog = glslang_shader_get_info_log(shader)
//            throw SPVError(errorDescription: String(cString: errorLog!))
//        }
//        
//        // Create and link program
//        let program = glslang_program_create()
//        defer { glslang_program_delete(program) }
//        
//        glslang_program_add_shader(program, shader)
//        
//        guard glslang_program_link(program, Int32(GLSLANG_MSG_SPV_RULES_BIT.rawValue | GLSLANG_MSG_VULKAN_RULES_BIT.rawValue)) == 0 else {
//            let errorLog = glslang_program_get_info_log(program)
//            throw SPVError(errorDescription: String(cString: errorLog!))
//        }
//        
//        // Generate SPIR-V
//        glslang_program_SPIRV_generate(program, stages[stage]!)
//        
//        // Get SPIR-V size and data
//        let size = glslang_program_SPIRV_get_size(program)
//        var spirvData = Data(count: size * MemoryLayout<UInt32>.size)
//        
//        spirvData.withUnsafeMutableBytes { buffer in
//            glslang_program_SPIRV_get(program, buffer.bindMemory(to: UInt32.self).baseAddress)
//        }
//        
//        return spirvData
        return Data()
    }
}
