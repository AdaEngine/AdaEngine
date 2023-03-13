//
//  spriv_compiler.hpp
//  
//
//  Created by v.prusakov on 3/11/23.
//

#ifndef spriv_compiler_hpp
#define spriv_compiler_hpp

#include <stdint.h>
#include <vector>

enum shaderc_stage {
    SHADER_STAGE_VERTEX,
    SHADER_STAGE_FRAGMENT,
    SHADER_STAGE_TESSELATION_CONTROL,
    SHADER_STAGE_TESSELATION_EVALUATION,
    SHADER_STAGE_COMPUTE,
    SHADER_STAGE_MAX,
};

enum shaderc_result {
    SHADERC_SUCCESS = 0,
    SHADERC_FAILURE = 1
};

typedef struct spirv_bin {
    std::vector<uint32_t> bin;
} spirv_bin;

bool glslang_init_process();
void glslang_deinit_process();

shaderc_result compile_shader_glsl(
                                   const char *source,
                                   shaderc_stage stage,
                                   spirv_bin *result_spriv_bin,
                                   const char **error
                                   );

#endif /* spriv_compiler_hpp */
