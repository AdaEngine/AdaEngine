#ifndef GRAVITY_AOT_RUNTIME_H
#define GRAVITY_AOT_RUNTIME_H
/* Experimental standalone ABI. No bytecode VM dependency.
 * Context, allocation arena and host handles belong to the caller. */
#include <stdint.h>
#include <stddef.h>
/* Keep ordinary object/metadata operations usable in freestanding targets.
 * Floating remainder uses the target C math runtime (IEEE remainder, as in VM). */
#ifdef __cplusplus
extern "C" double remainder(double, double) noexcept;
#else
extern double remainder(double, double);
#endif
static inline int gravity_aot_text_compare(const char *a, const char *b) {
    while (*a && *a==*b) { ++a; ++b; }
    return (unsigned char)*a-(unsigned char)*b;
}
static inline int gravity_aot_bytes_compare(const char *a, const char *b, size_t count) {
    for (size_t i=0; i<count; ++i) if ((unsigned char)a[i]!=(unsigned char)b[i]) return (unsigned char)a[i]-(unsigned char)b[i];
    return 0;
}
static inline int gravity_aot_finite(double value) {
    uint64_t bits=0;
    const unsigned char *source=(const unsigned char *)&value;
    unsigned char *target=(unsigned char *)&bits;
    for (size_t i=0; i<sizeof(bits); ++i) target[i]=source[i];
    return (bits & UINT64_C(0x7ff0000000000000)) != UINT64_C(0x7ff0000000000000);
}
typedef char gravity_aot_double_must_be_64_bits[sizeof(double)==sizeof(uint64_t)?1:-1];
#define GRAVITY_AOT_ABI_VERSION 3u

enum { GRAVITY_AOT_NULL, GRAVITY_AOT_INT, GRAVITY_AOT_BOOL, GRAVITY_AOT_FLOAT,
       GRAVITY_AOT_STRING, GRAVITY_AOT_OBJECT, GRAVITY_AOT_HOST, GRAVITY_AOT_LIST, GRAVITY_AOT_RANGE, GRAVITY_AOT_TASK, GRAVITY_AOT_DURABLE_HOST };
enum { GRAVITY_AOT_OK, GRAVITY_AOT_BAD_ABI, GRAVITY_AOT_ARITY, GRAVITY_AOT_TYPE,
       GRAVITY_AOT_DIV_ZERO, GRAVITY_AOT_LIMIT, GRAVITY_AOT_MEMORY, GRAVITY_AOT_FIELD,
       GRAVITY_AOT_METHOD, GRAVITY_AOT_HOST_ERROR, GRAVITY_AOT_STALE_HANDLE, GRAVITY_AOT_CANCELLED };
enum { GA_ADD, GA_SUB, GA_MUL, GA_DIV, GA_REM, GA_LT, GA_LE, GA_GT, GA_GE,
       GA_EQ, GA_NE, GA_AND, GA_OR, GA_NEG, GA_NOT };
enum { GRAVITY_AOT_DECL_FUNCTION, GRAVITY_AOT_DECL_CLASS, GRAVITY_AOT_DECL_STRUCT,
       GRAVITY_AOT_DECL_FIELD, GRAVITY_AOT_DECL_METHOD };
enum { GRAVITY_AOT_ATTR_IDENTIFIER, GRAVITY_AOT_ATTR_STRING, GRAVITY_AOT_ATTR_INT,
       GRAVITY_AOT_ATTR_FLOAT, GRAVITY_AOT_ATTR_BOOL, GRAVITY_AOT_ATTR_NULL, GRAVITY_AOT_ATTR_LIST };

typedef struct gravity_aot_object gravity_aot_object;
typedef struct gravity_aot_context gravity_aot_context;
typedef struct gravity_aot_class gravity_aot_class;
typedef struct gravity_aot_list gravity_aot_list;
typedef struct gravity_aot_range gravity_aot_range;
typedef struct gravity_aot_task gravity_aot_task;
typedef struct {
    union { int64_t integer; double floating; const char *string; gravity_aot_object *object;
            void *handle; gravity_aot_list *list; gravity_aot_range *range; gravity_aot_task *task; };
    uint32_t kind, length; /* string length, or host generation for a borrowed handle */
} gravity_aot_value;
typedef struct gravity_aot_attribute_value {
    uint32_t kind, count;
    const char *text;
    int64_t integer;
    double floating;
    const struct gravity_aot_attribute_value *const *items;
} gravity_aot_attribute_value;
typedef struct { const char *label; const gravity_aot_attribute_value *value; } gravity_aot_attribute_argument;
typedef struct {
    const char *name;
    uint32_t argument_count, fileid, line, column;
    const gravity_aot_attribute_argument *arguments;
} gravity_aot_attribute;
typedef struct { const char *name, *type_name; } gravity_aot_parameter;
typedef struct {
    const char *name, *parent, *type_name;
    uint32_t kind, fileid, line, column, attribute_count;
    const gravity_aot_attribute *attributes;
    uint32_t parameter_count;
    const gravity_aot_parameter *parameters;
} gravity_aot_declaration;
typedef gravity_aot_value (*gravity_aot_function)(gravity_aot_context *, const gravity_aot_value *, uint32_t);
typedef gravity_aot_value (*gravity_aot_method)(gravity_aot_context *, gravity_aot_value, const gravity_aot_value *, uint32_t);
typedef struct {
    const char *name;
    uint32_t arity;
    gravity_aot_function call;
    const gravity_aot_declaration *declaration;
} gravity_aot_export;
typedef struct {
    const gravity_aot_declaration *declaration;
    gravity_aot_value default_value;
    uint32_t readonly;
    gravity_aot_value (*initialize)(gravity_aot_context *, gravity_aot_value);
} gravity_aot_field;
typedef struct {
    const char *name;
    uint32_t arity;
    gravity_aot_method call;
    const gravity_aot_declaration *declaration;
} gravity_aot_method_export;
struct gravity_aot_class {
    const gravity_aot_declaration *declaration;
    uint32_t is_struct, field_count, method_count;
    const gravity_aot_field *fields;
    const gravity_aot_method_export *methods;
};
struct gravity_aot_object { const gravity_aot_class *type; gravity_aot_value *fields; };
struct gravity_aot_list { uint32_t count; gravity_aot_value *items; };
struct gravity_aot_range { int64_t start, end; uint32_t inclusive; };
typedef struct {
    uint32_t abi_version, count;
    const gravity_aot_export *exports;
    uint32_t type_count, declaration_count;
    const gravity_aot_class *types;
    const gravity_aot_declaration *declarations;
} gravity_aot_module;
/* Callback result: get/set/call return 1 on success; next returns 1/value,
 * 0/end or -1/error. Returned borrowed handles must use the context generation. */
typedef struct {
    int (*get)(void *, gravity_aot_value, const char *, gravity_aot_value *);
    int (*set)(void *, gravity_aot_value, const char *, gravity_aot_value);
    int (*call)(void *, gravity_aot_value, const char *, const gravity_aot_value *, uint32_t, gravity_aot_value *);
    int (*next)(void *, gravity_aot_value, uint64_t *, gravity_aot_value *);
} gravity_aot_host;
struct gravity_aot_context {
    uint32_t abi_version, error;
    uint64_t fuel;
    uint32_t depth, max_depth, host_generation;
    void *allocation_data;
    void *(*allocate)(void *, size_t);
    void *host_data;
    const gravity_aot_host *host;
};
static inline gravity_aot_context gravity_aot_context_init(uint64_t fuel) {
    gravity_aot_context c = {0}; c.abi_version = GRAVITY_AOT_ABI_VERSION;
    c.fuel = fuel; c.max_depth = 256; c.host_generation = 1; return c;
}
static inline gravity_aot_value gravity_aot_null(void) {
    gravity_aot_value v = {0}; return v;
}
static inline gravity_aot_value gravity_aot_int(int64_t n) {
    gravity_aot_value v = {0}; v.integer = n; v.kind = GRAVITY_AOT_INT; return v;
}
static inline gravity_aot_value gravity_aot_bool(int n) {
    gravity_aot_value v = {0}; v.integer = !!n; v.kind = GRAVITY_AOT_BOOL; return v;
}
static inline gravity_aot_value gravity_aot_float(double n) {
    gravity_aot_value v = {0}; v.floating = n; v.kind = GRAVITY_AOT_FLOAT; return v;
}
static inline gravity_aot_value gravity_aot_string(const char *s, uint32_t length) {
    gravity_aot_value v = {0}; v.string = s; v.kind = GRAVITY_AOT_STRING; v.length = length; return v;
}
static inline gravity_aot_value gravity_aot_host_ref(gravity_aot_context *c, void *handle) {
    gravity_aot_value v = {0}; v.handle = handle; v.kind = GRAVITY_AOT_HOST; v.length = c->host_generation; return v;
}
static inline void gravity_aot_error(gravity_aot_context *c, uint32_t error) { if (!c->error) c->error = error; }
static inline int gravity_aot_valid(gravity_aot_context *c, gravity_aot_value v) {
    if (v.kind > GRAVITY_AOT_DURABLE_HOST) gravity_aot_error(c, GRAVITY_AOT_TYPE);
    if (v.kind == GRAVITY_AOT_HOST && v.length != c->host_generation) gravity_aot_error(c, GRAVITY_AOT_STALE_HANDLE);
    return !c->error;
}
static inline int gravity_aot_tick(gravity_aot_context *c) {
    if (c->error) return 0;
    if (!c->fuel) { gravity_aot_error(c, GRAVITY_AOT_LIMIT); return 0; }
    --c->fuel; return 1;
}
static inline int gravity_aot_truth(gravity_aot_context *c, gravity_aot_value v) {
    if (!gravity_aot_valid(c, v)) return 0;
    if (v.kind == GRAVITY_AOT_NULL) return 0;
    if (v.kind == GRAVITY_AOT_FLOAT) return v.floating != 0.0;
    if (v.kind == GRAVITY_AOT_STRING) return v.length != 0;
    if (v.kind == GRAVITY_AOT_INT || v.kind == GRAVITY_AOT_BOOL) return v.integer != 0;
    return 1;
}
static inline double gravity_aot_number(gravity_aot_value v) { return v.kind == GRAVITY_AOT_FLOAT ? v.floating : (double)v.integer; }
static inline int64_t gravity_aot_integer(gravity_aot_context *c, gravity_aot_value v) {
    if (v.kind != GRAVITY_AOT_FLOAT) return v.integer;
    if (!gravity_aot_finite(v.floating) || v.floating >= 9223372036854775808.0 || v.floating < -9223372036854775808.0) {
        gravity_aot_error(c, GRAVITY_AOT_TYPE); return 0;
    }
    return (int64_t)v.floating;
}
static inline gravity_aot_value gravity_aot_binary(gravity_aot_context *c, int op, gravity_aot_value a, gravity_aot_value b) {
    if (!gravity_aot_valid(c, a) || !gravity_aot_valid(c, b)) return gravity_aot_null();
    if (op == GA_AND || op == GA_OR) {
        int x = gravity_aot_truth(c, a), y = gravity_aot_truth(c, b);
        return gravity_aot_bool(op == GA_AND ? x && y : x || y);
    }
    if (a.kind == GRAVITY_AOT_STRING && b.kind == GRAVITY_AOT_STRING && op >= GA_LT && op <= GA_NE) {
        uint32_t n = a.length < b.length ? a.length : b.length;
        int cmp = gravity_aot_bytes_compare(a.string, b.string, n);
        if (!cmp) cmp = a.length > b.length ? 1 : a.length < b.length ? -1 : 0;
        return gravity_aot_bool(op == GA_EQ ? !cmp : op == GA_NE ? !!cmp : op == GA_LT ? cmp < 0 :
                                op == GA_LE ? cmp <= 0 : op == GA_GT ? cmp > 0 : cmp >= 0);
    }
    if (a.kind > GRAVITY_AOT_FLOAT || b.kind > GRAVITY_AOT_FLOAT) {
        if (op == GA_EQ || op == GA_NE) {
            int equal = a.kind == b.kind && a.handle == b.handle;
            return gravity_aot_bool(op == GA_EQ ? equal : !equal);
        }
        gravity_aot_error(c, GRAVITY_AOT_TYPE); return gravity_aot_null();
    }
    if ((op == GA_DIV || op == GA_REM) && (b.kind == GRAVITY_AOT_NULL ||
        (b.kind == GRAVITY_AOT_INT && !b.integer) || (b.kind == GRAVITY_AOT_FLOAT && b.floating == 0.0))) {
        gravity_aot_error(c, GRAVITY_AOT_DIV_ZERO); return gravity_aot_null();
    }
    if (a.kind == GRAVITY_AOT_NULL && op < GA_LT) {
        if (op == GA_ADD) return b;
        if (op == GA_MUL || op == GA_DIV || op == GA_REM) return gravity_aot_int(0);
    }
    int float_math = a.kind == GRAVITY_AOT_FLOAT ||
        (a.kind == GRAVITY_AOT_INT && b.kind == GRAVITY_AOT_FLOAT && op != GA_REM) ||
        (op >= GA_LT && b.kind == GRAVITY_AOT_FLOAT);
    if (float_math) {
        double x = gravity_aot_number(a), y = gravity_aot_number(b);
        switch (op) {
            case GA_ADD: return gravity_aot_float(x+y); case GA_SUB: return gravity_aot_float(x-y);
            case GA_MUL: return gravity_aot_float(x*y);
            case GA_DIV: case GA_REM:
                if (y == 0.0) { gravity_aot_error(c, GRAVITY_AOT_DIV_ZERO); return gravity_aot_null(); }
                return gravity_aot_float(op == GA_DIV ? x/y : remainder(x,y));
            case GA_LT: return gravity_aot_bool(x<y); case GA_LE: return gravity_aot_bool(x<=y);
            case GA_GT: return gravity_aot_bool(x>y); case GA_GE: return gravity_aot_bool(x>=y);
            case GA_EQ: return gravity_aot_bool(x==y); case GA_NE: return gravity_aot_bool(x!=y);
        }
    }
    int64_t x = gravity_aot_integer(c, a), y = gravity_aot_integer(c, b);
    if (c->error) return gravity_aot_null();
    switch (op) {
        case GA_ADD: return gravity_aot_int((int64_t)((uint64_t)x+(uint64_t)y));
        case GA_SUB: return gravity_aot_int((int64_t)((uint64_t)x-(uint64_t)y));
        case GA_MUL: return gravity_aot_int((int64_t)((uint64_t)x*(uint64_t)y));
        case GA_DIV: case GA_REM:
            if (!y) { gravity_aot_error(c, GRAVITY_AOT_DIV_ZERO); return gravity_aot_null(); }
            if (x == INT64_MIN && y == -1) return gravity_aot_int(op == GA_DIV ? INT64_MIN : 0);
            return gravity_aot_int(op == GA_DIV ? x/y : x%y);
        case GA_LT: return gravity_aot_bool(x<y); case GA_LE: return gravity_aot_bool(x<=y);
        case GA_GT: return gravity_aot_bool(x>y); case GA_GE: return gravity_aot_bool(x>=y);
        case GA_EQ: return gravity_aot_bool(x==y); case GA_NE: return gravity_aot_bool(x!=y);
        default: gravity_aot_error(c, GRAVITY_AOT_TYPE); return gravity_aot_null();
    }
}
static inline gravity_aot_value gravity_aot_unary(gravity_aot_context *c, int op, gravity_aot_value v) {
    if (op == GA_NOT) return gravity_aot_bool(!gravity_aot_truth(c, v));
    if (!gravity_aot_valid(c, v)) return gravity_aot_null();
    if (v.kind == GRAVITY_AOT_NULL) return gravity_aot_bool(0);
    if (v.kind == GRAVITY_AOT_FLOAT) return gravity_aot_float(-v.floating);
    if (v.kind > GRAVITY_AOT_BOOL) { gravity_aot_error(c, GRAVITY_AOT_TYPE); return gravity_aot_null(); }
    return gravity_aot_int((int64_t)(UINT64_C(0)-(uint64_t)v.integer));
}
static inline void *gravity_aot_allocate(gravity_aot_context *,size_t);
static inline gravity_aot_value gravity_aot_copy(gravity_aot_context *,gravity_aot_value);
static inline gravity_aot_value gravity_aot_call(gravity_aot_context *,gravity_aot_value,const char *,const gravity_aot_value *,uint32_t);
static inline gravity_aot_value gravity_aot_task_call(gravity_aot_context *,gravity_aot_value,const char *,const gravity_aot_value *,uint32_t);
#include "gravity_aot_objects.h"
#include "gravity_aot_tasks.h"
#endif
