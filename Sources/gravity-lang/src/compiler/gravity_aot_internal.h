#ifndef GRAVITY_AOT_INTERNAL_H
#define GRAVITY_AOT_INTERNAL_H
#include "gravity_aot.h"
#include "../shared/gravity_aot_runtime.h"
typedef struct {
    FILE *out;
    gravity_delegate_t *delegate;
    const char *prefix;
    gnode_r *functions, *classes, *declarations;
    gnode_function_decl_t *function;
    gnode_class_decl_t *owner;
    unsigned temporary, loop_depth, metadata_serial, suspension;
    bool failed;
} emitter;
bool ga_fail(emitter *, gnode_t *, const char *);
void ga_put(emitter *, const char *, ...);
void ga_string(emitter *, const char *, size_t);
int ga_class_index(emitter *, gnode_t *);
int ga_declaration_index(emitter *, gnode_t *);
void ga_function_name(emitter *, gnode_function_decl_t *);
gnode_class_decl_t *ga_function_owner(emitter *, gnode_function_decl_t *);
void ga_metadata(emitter *);
bool ga_constant_default(gnode_t *);
#endif
