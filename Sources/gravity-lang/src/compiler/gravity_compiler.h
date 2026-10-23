//
//  gravity_compiler.h
//  gravity
//
//  Created by Marco Bambini on 29/08/14.
//  Copyright (c) 2014 CreoLabs. All rights reserved.
//

#ifndef __GRAVITY_COMPILER__
#define __GRAVITY_COMPILER__

#include "../shared/gravity_delegate.h"
#include "debug_macros.h"
#include "../utils/gravity_utils.h"
#include "../shared/gravity_value.h"
#include "gravity_ast.h"

#ifdef __cplusplus
extern "C" {
#endif

// opaque compiler data type
typedef struct gravity_compiler_t   gravity_compiler_t;

GRAVITY_API gravity_compiler_t  *gravity_compiler_create (gravity_delegate_t *delegate);
GRAVITY_API gravity_closure_t   *gravity_compiler_run (gravity_compiler_t *compiler, const char *source, size_t len, uint32_t fileid, bool is_static, bool add_debug);

GRAVITY_API gnode_t  *gravity_compiler_ast (gravity_compiler_t *compiler);
GRAVITY_API void      gravity_compiler_free (gravity_compiler_t *compiler);
GRAVITY_API json_t   *gravity_compiler_serialize (gravity_compiler_t *compiler, gravity_closure_t *closure);
GRAVITY_API bool      gravity_compiler_serialize_infile (gravity_compiler_t *compiler, gravity_closure_t *closure, const char *path);
GRAVITY_API void      gravity_compiler_transfer (gravity_compiler_t *compiler, gravity_vm *vm);

GRAVITY_API uint32_t gravity_compiler_annotation_count(gravity_compiler_t *compiler);
GRAVITY_API const gravity_annotation_t *gravity_compiler_annotation_at(gravity_compiler_t *compiler, uint32_t index);
GRAVITY_API const char *gravity_annotation_name(const gravity_annotation_t *annotation);
GRAVITY_API uint32_t gravity_annotation_line(const gravity_annotation_t *annotation);
GRAVITY_API uint32_t gravity_annotation_column(const gravity_annotation_t *annotation);
GRAVITY_API uint32_t gravity_annotation_fileid(const gravity_annotation_t *annotation);
GRAVITY_API uint32_t gravity_annotation_target_kind(const gravity_annotation_t *annotation);
GRAVITY_API const char *gravity_annotation_target_identifier(const gravity_annotation_t *annotation);
GRAVITY_API const char *gravity_annotation_target_parent_identifier(const gravity_annotation_t *annotation);
GRAVITY_API uint32_t gravity_annotation_argument_count(const gravity_annotation_t *annotation);
GRAVITY_API const char *gravity_annotation_argument_label(const gravity_annotation_t *annotation, uint32_t index);
GRAVITY_API const gravity_annotation_value_t *gravity_annotation_argument_value(const gravity_annotation_t *annotation, uint32_t index);
GRAVITY_API uint32_t gravity_annotation_value_kind_get(const gravity_annotation_value_t *value);
GRAVITY_API const char *gravity_annotation_value_string(const gravity_annotation_value_t *value);
GRAVITY_API int64_t gravity_annotation_value_int(const gravity_annotation_value_t *value);
GRAVITY_API double gravity_annotation_value_float(const gravity_annotation_value_t *value);
GRAVITY_API bool gravity_annotation_value_bool(const gravity_annotation_value_t *value);
GRAVITY_API uint32_t gravity_annotation_value_count(const gravity_annotation_value_t *value);
GRAVITY_API const gravity_annotation_value_t *gravity_annotation_value_at(const gravity_annotation_value_t *value, uint32_t index);

/* Parse and resolve a native AST without generating VM bytecode or Fiber wrappers. */
GRAVITY_API bool gravity_compiler_prepare_native(gravity_compiler_t *, const char *, size_t, uint32_t);

#ifdef __cplusplus
}
#endif

#endif
