//
//  spriv_compiler.hpp
//  AdaEngine
//
//  Created by v.prusakov on 3/11/23.
//

#ifndef spriv_compiler_hpp
#define spriv_compiler_hpp

#include <stdint.h>

enum shaderc_stage {
    SHADER_STAGE_VERTEX,
    SHADER_STAGE_FRAGMENT,
    SHADER_STAGE_TESSELATION_CONTROL,
    SHADER_STAGE_TESSELATION_EVALUATION,
    SHADER_STAGE_COMPUTE,
    SHADER_STAGE_MAX,
};

struct spirv_options {
    const char* preamble;
};

struct spirv_bin {
    const void *bytes;
    size_t length;
};

int glslang_init_process();
void glslang_deinit_process();

struct spirv_bin compile_shader_glsl(
                              const char *source,
                              enum shaderc_stage stage,
                              struct spirv_options options,
                              const char **error
                              );

#endif /* spriv_compiler_hpp */
