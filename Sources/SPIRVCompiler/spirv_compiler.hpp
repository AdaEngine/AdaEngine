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

struct spirv_bin {
    const void *bytes;
    size_t length;
};

bool glslang_init_process();
void glslang_deinit_process();

spirv_bin compile_shader_glsl(
                              const char *source,
                              shaderc_stage stage,
                              const char **error
                              );

#endif /* spriv_compiler_hpp */
