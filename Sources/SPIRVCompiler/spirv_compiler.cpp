//
//  spriv_compiler.cpp
//  
//
//  Created by v.prusakov on 3/11/23.
//

#include "spirv_compiler.hpp"
#include "glslang_resource_limits.h"

#include <glslang/Include/Types.h>
#include <glslang/Public/ShaderLang.h>
#include <SPIRV/GlslangToSpv.h>

bool glslang_init_process() {
    return glslang::InitializeProcess();
}

void glslang_deinit_process() {
    glslang::FinalizeProcess();
}

shaderc_result compile_shader_glsl(const char *source, ShaderStage stage, spirv_bin *result_spriv_bin, const char **error) {
        
    EShLanguage stages[ShaderStage::SHADER_STAGE_MAX] = {
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
    
    std::string pre_processed_code;
    EShMessages message = (EShMessages)(EShMsgSpvRules | EShMsgVulkanRules);
    
    if (!shader.preprocess(&DefaultTBuiltInResource, DefaultVersion, ENoProfile, false, false, message, &pre_processed_code, includer)) {
        printf("%s", shader.getInfoLog());
        *error = "failed to preprocess a shader";
        return shaderc_result::SHADERC_FAILURE;
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
    
        return shaderc_result::SHADERC_FAILURE;
    }
    
    glslang::TProgram program;
    program.addShader(&shader);
    
    if (!program.link(message)) {
        printf("%s", shader.getInfoLog());
        *error = "failed to link a programm";
        return shaderc_result::SHADERC_FAILURE;
    }
    
    std::vector<uint32_t> SpirV;
    spv::SpvBuildLogger logger;
    glslang::SpvOptions spvOptions;
    glslang::GlslangToSpv(*program.getIntermediate(stages[stage]), SpirV, &logger, &spvOptions);
    
    result_spriv_bin->bytes = (const void *)SpirV.data();
    result_spriv_bin->length = (int)(SpirV.size() * sizeof(uint32_t));
    
    return shaderc_result::SHADERC_SUCCESS;
}
