//
//  glslang.h
//  TEST
//
//  Created by Vladislav Prusakov on 20.04.2025.
//

#ifndef spriv_compiler_hpp
#define spriv_compiler_hpp

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

typedef enum {
    SHADER_STAGE_VERTEX,
    SHADER_STAGE_FRAGMENT,
    SHADER_STAGE_TESSELATION_CONTROL,
    SHADER_STAGE_TESSELATION_EVALUATION,
    SHADER_STAGE_COMPUTE,
    SHADER_STAGE_MAX,
} shaderc_stage;

typedef struct {
    const char* preamble;
} spirv_options;

typedef struct {
    const void *bytes;
    unsigned long length;
} spirv_bin;

int glslang_initialize(void);
void glslang_finalize(void);

spirv_bin compile_shader_glsl(
                              const char *source,
                              shaderc_stage stage,
                              spirv_options options,
                              const char **error
                              );

#ifdef __cplusplus
}
#endif

#endif /* spriv_compiler_hpp */
