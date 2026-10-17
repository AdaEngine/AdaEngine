#ifndef GRAVITY_AOT_H
#define GRAVITY_AOT_H
#include "gravity_compiler.h"
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif
/* Generate portable C from a successfully compiled module's checked AST.
 * Unsupported constructs report a source-located semantic error. Output is
 * staged before writing: a semantic failure leaves the output stream untouched.
 * prefix must be an ASCII identifier starting with an alphabetic character.
 * The compiler retains ownership of its AST. No VM execution is performed. */
GRAVITY_API bool gravity_compiler_emit_c(gravity_compiler_t *compiler, FILE *output,
                                       const char *prefix, gravity_delegate_t *delegate);
#ifdef __cplusplus
}
#endif
#endif
