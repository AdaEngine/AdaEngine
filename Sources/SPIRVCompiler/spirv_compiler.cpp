//
//  spriv_compiler.cpp
//  AdaEngine
//
//  Created by v.prusakov on 3/11/23.
//

#include "spirv_compiler.h"

#include <glslang/Include/ResourceLimits.h>
#include <glslang/Include/Types.h>
#include <glslang/Public/ShaderLang.h>
#include <SPIRV/GlslangToSpv.h>

const TBuiltInResource DefaultTBuiltInResource = {
    /* .MaxLights = */ 32,
    /* .MaxClipPlanes = */ 6,
    /* .MaxTextureUnits = */ 32,
    /* .MaxTextureCoords = */ 32,
    /* .MaxVertexAttribs = */ 64,
    /* .MaxVertexUniformComponents = */ 4096,
    /* .MaxVaryingFloats = */ 64,
    /* .MaxVertexTextureImageUnits = */ 32,
    /* .MaxCombinedTextureImageUnits = */ 80,
    /* .MaxTextureImageUnits = */ 32,
    /* .MaxFragmentUniformComponents = */ 4096,
    /* .MaxDrawBuffers = */ 32,
    /* .MaxVertexUniformVectors = */ 128,
    /* .MaxVaryingVectors = */ 8,
    /* .MaxFragmentUniformVectors = */ 16,
    /* .MaxVertexOutputVectors = */ 16,
    /* .MaxFragmentInputVectors = */ 15,
    /* .MinProgramTexelOffset = */ -8,
    /* .MaxProgramTexelOffset = */ 7,
    /* .MaxClipDistances = */ 8,
    /* .MaxComputeWorkGroupCountX = */ 65535,
    /* .MaxComputeWorkGroupCountY = */ 65535,
    /* .MaxComputeWorkGroupCountZ = */ 65535,
    /* .MaxComputeWorkGroupSizeX = */ 1024,
    /* .MaxComputeWorkGroupSizeY = */ 1024,
    /* .MaxComputeWorkGroupSizeZ = */ 64,
    /* .MaxComputeUniformComponents = */ 1024,
    /* .MaxComputeTextureImageUnits = */ 16,
    /* .MaxComputeImageUniforms = */ 8,
    /* .MaxComputeAtomicCounters = */ 8,
    /* .MaxComputeAtomicCounterBuffers = */ 1,
    /* .MaxVaryingComponents = */ 60,
    /* .MaxVertexOutputComponents = */ 64,
    /* .MaxGeometryInputComponents = */ 64,
    /* .MaxGeometryOutputComponents = */ 128,
    /* .MaxFragmentInputComponents = */ 128,
    /* .MaxImageUnits = */ 8,
    /* .MaxCombinedImageUnitsAndFragmentOutputs = */ 8,
    /* .MaxCombinedShaderOutputResources = */ 8,
    /* .MaxImageSamples = */ 0,
    /* .MaxVertexImageUniforms = */ 0,
    /* .MaxTessControlImageUniforms = */ 0,
    /* .MaxTessEvaluationImageUniforms = */ 0,
    /* .MaxGeometryImageUniforms = */ 0,
    /* .MaxFragmentImageUniforms = */ 8,
    /* .MaxCombinedImageUniforms = */ 8,
    /* .MaxGeometryTextureImageUnits = */ 16,
    /* .MaxGeometryOutputVertices = */ 256,
    /* .MaxGeometryTotalOutputComponents = */ 1024,
    /* .MaxGeometryUniformComponents = */ 1024,
    /* .MaxGeometryVaryingComponents = */ 64,
    /* .MaxTessControlInputComponents = */ 128,
    /* .MaxTessControlOutputComponents = */ 128,
    /* .MaxTessControlTextureImageUnits = */ 16,
    /* .MaxTessControlUniformComponents = */ 1024,
    /* .MaxTessControlTotalOutputComponents = */ 4096,
    /* .MaxTessEvaluationInputComponents = */ 128,
    /* .MaxTessEvaluationOutputComponents = */ 128,
    /* .MaxTessEvaluationTextureImageUnits = */ 16,
    /* .MaxTessEvaluationUniformComponents = */ 1024,
    /* .MaxTessPatchComponents = */ 120,
    /* .MaxPatchVertices = */ 32,
    /* .MaxTessGenLevel = */ 64,
    /* .MaxViewports = */ 16,
    /* .MaxVertexAtomicCounters = */ 0,
    /* .MaxTessControlAtomicCounters = */ 0,
    /* .MaxTessEvaluationAtomicCounters = */ 0,
    /* .MaxGeometryAtomicCounters = */ 0,
    /* .MaxFragmentAtomicCounters = */ 8,
    /* .MaxCombinedAtomicCounters = */ 8,
    /* .MaxAtomicCounterBindings = */ 1,
    /* .MaxVertexAtomicCounterBuffers = */ 0,
    /* .MaxTessControlAtomicCounterBuffers = */ 0,
    /* .MaxTessEvaluationAtomicCounterBuffers = */ 0,
    /* .MaxGeometryAtomicCounterBuffers = */ 0,
    /* .MaxFragmentAtomicCounterBuffers = */ 1,
    /* .MaxCombinedAtomicCounterBuffers = */ 1,
    /* .MaxAtomicCounterBufferSize = */ 16384,
    /* .MaxTransformFeedbackBuffers = */ 4,
    /* .MaxTransformFeedbackInterleavedComponents = */ 64,
    /* .MaxCullDistances = */ 8,
    /* .MaxCombinedClipAndCullDistances = */ 8,
    /* .MaxSamples = */ 4,
    /* .maxMeshOutputVerticesNV = */ 256,
    /* .maxMeshOutputPrimitivesNV = */ 512,
    /* .maxMeshWorkGroupSizeX_NV = */ 32,
    /* .maxMeshWorkGroupSizeY_NV = */ 1,
    /* .maxMeshWorkGroupSizeZ_NV = */ 1,
    /* .maxTaskWorkGroupSizeX_NV = */ 32,
    /* .maxTaskWorkGroupSizeY_NV = */ 1,
    /* .maxTaskWorkGroupSizeZ_NV = */ 1,
    /* .maxMeshViewCountNV = */ 4,
    /* .maxMeshOutputVerticesEXT = */ 256,
    /* .maxMeshOutputPrimitivesEXT = */ 256,
    /* .maxMeshWorkGroupSizeX_EXT = */ 128,
    /* .maxMeshWorkGroupSizeY_EXT = */ 128,
    /* .maxMeshWorkGroupSizeZ_EXT = */ 128,
    /* .maxTaskWorkGroupSizeX_EXT = */ 128,
    /* .maxTaskWorkGroupSizeY_EXT = */ 128,
    /* .maxTaskWorkGroupSizeZ_EXT = */ 128,
    /* .maxMeshViewCountEXT = */ 4,
    /* .maxDualSourceDrawBuffersEXT = */ 1,

    /* .limits = */ {
            /* .nonInductiveForLoops = */ true,
            /* .whileLoops = */ true,
            /* .doWhileLoops = */ true,
            /* .generalUniformIndexing = */ true,
            /* .generalAttributeMatrixVectorIndexing = */ true,
            /* .generalVaryingIndexing = */ true,
            /* .generalSamplerIndexing = */ true,
            /* .generalVariableIndexing = */ true,
            /* .generalConstantMatrixVectorIndexing = */ true,
    }
};

int glslang_initialize() {
    return glslang::InitializeProcess();
}

void glslang_finalize() {
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
    int DefaultVersion = 410;
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
        printf("===== GLSL PREPROCESSING ERROR =====\n");
        printf("Shader source:\n%s\n", source);
        printf("Preprocessor error:\n%s\n", shader.getInfoDebugLog());
        printf("===================================\n");
        *error = "failed to preprocess a shader";
        return {};
    }
    
    cs_strings = pre_processed_code.c_str();
    
    shader.setStrings(&cs_strings, 1);
    
    if (!shader.parse(&DefaultTBuiltInResource, DefaultVersion, false, message)) {
        printf("===== GLSL PARSE ERROR =====\n");
        printf("Shader source:\n%s\n", source);
        printf("Preprocessor error:\n%s\n", shader.getInfoDebugLog());
        printf("===================================\n");
        *error = "failed to parse a shader";
        printf("%s", shader.getInfoLog());
        
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
