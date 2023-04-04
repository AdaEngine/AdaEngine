//
//  spriv_compiler.cpp
//  
//
//  Created by v.prusakov on 3/11/23.
//

#include "spirv_compiler.hpp"
#include "glslang_resource_limits.hpp"

#include <glslang/Include/Types.h>
#include <glslang/Public/ShaderLang.h>
#include <SPIRV/GlslangToSpv.h>

bool glslang_init_process() {
    return glslang::InitializeProcess();
}

void glslang_deinit_process() {
    glslang::FinalizeProcess();
}

spirv_bin compile_shader_glsl(
                              const char *source,
                              shaderc_stage stage,
                              spirv_options options,
                              const char **error
                              ) {
    
    EShLanguage stages[shaderc_stage::SHADER_STAGE_MAX] = {
        EShLangVertex,
        EShLangFragment,
        EShLangTessControl,
        EShLangTessEvaluation,
        EShLangCompute
    };
    
    const char *cs_strings = source;
    
    int ClientInputSemanticsVersion = 100;
    int DefaultVersion = 100;
    glslang::EShTargetClientVersion ClientVersion = glslang::EShTargetVulkan_1_2;
    glslang::EShTargetLanguageVersion TargetVersion = glslang::EShTargetSpv_1_5;
    
    glslang::TShader::ForbidIncluder includer;
    glslang::TShader shader(stages[stage]);
    shader.setStrings(&cs_strings, 1);
    shader.setEnvInput(glslang::EShSourceGlsl, stages[stage], glslang::EShClientVulkan, ClientInputSemanticsVersion);
    shader.setEnvClient(glslang::EShClientVulkan, ClientVersion);
    shader.setEnvTarget(glslang::EShTargetSpv, TargetVersion);
    
    if (options.preamble) {
        shader.setPreamble(options.preamble);
    }

    std::string pre_processed_code;
    EShMessages message = (EShMessages)(EShMsgSpvRules | EShMsgVulkanRules);
    
    if (!shader.preprocess(&DefaultTBuiltInResource, DefaultVersion, ENoProfile, false, false, message, &pre_processed_code, includer)) {
        printf("%s", shader.getInfoLog());
        *error = "failed to preprocess a shader";
        return {};
    }
    
    cs_strings = pre_processed_code.c_str();
    
    shader.setStrings(&cs_strings, 1);
    
    if (!shader.parse(&DefaultTBuiltInResource, DefaultVersion, false, message)) {
        printf("%s", shader.getInfoLog());
        *error = "failed to parse shader";
        //        errorMsg += shader.getInfoLog();
        //        errorMsg += "\n";
        //        errorMsg += shader.getInfoDebugLog();
        //        *error = errorMsg.c_str();
        
        return {};
    }
    
    glslang::TProgram program;
    program.addShader(&shader);
    
    if (!program.link(message)) {
        printf("%s", program.getInfoLog());
        *error = "failed to link a programm";
        return {};
    }
    
    std::vector<uint32_t> SpirV;
    spv::SpvBuildLogger logger;
    glslang::SpvOptions spvOptions;
    glslang::GlslangToSpv(*program.getIntermediate(stages[stage]), SpirV, &logger, &spvOptions);
    
    spirv_bin result;
    uint32_t *buffer = new uint32_t[SpirV.size()];
    result.bytes = buffer;
    result.length = (SpirV.size() * sizeof(uint32_t));
    
    {
        memcpy(buffer, SpirV.data(), SpirV.size() * sizeof(uint32_t));
    }
    
    return result;
}
