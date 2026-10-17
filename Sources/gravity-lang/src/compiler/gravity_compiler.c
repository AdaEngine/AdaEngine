//
//  gravity_compiler.c
//  gravity
//
//  Created by Marco Bambini on 29/08/14.
//  Copyright (c) 2014 CreoLabs. All rights reserved.
//

#include "gravity_compiler.h"
#include "gravity_parser.h"
#include "gravity_token.h"
#include "../utils/gravity_utils.h"
#include "gravity_semacheck1.h"
#include "gravity_semacheck2.h"
#include "gravity_optimizer.h"
#include "gravity_codegen.h"
#include "../shared/gravity_array.h"
#include "../shared/gravity_hash.h"
#include "../runtime/gravity_core.h"

struct gravity_compiler_t {
    gravity_parser_t        *parser;
    gravity_delegate_t      *delegate;
    cstring_r               *storage;
    gravity_vm              *vm;
    gnode_t                 *ast;
    void_r                  *objects;
    void_r                  *annotations;
};

static void collect_annotations(gnode_t *node, void_r *annotations) {
    if (!node) return;
    if (node->annotations) {
        gtype_array_each(node->annotations, {marray_push(void *, *annotations, val);}, gravity_annotation_t *);
    }
    switch (node->tag) {
        case NODE_LIST_STAT:
        case NODE_COMPOUND_STAT: {
            gnode_compound_stmt_t *block = (gnode_compound_stmt_t *)node;
            gnode_array_each(block->stmts, {collect_annotations(val, annotations);});
            break;
        }
        case NODE_CLASS_DECL: {
            gnode_class_decl_t *declaration = (gnode_class_decl_t *)node;
            gnode_array_each(declaration->decls, {collect_annotations(val, annotations);});
            break;
        }
        case NODE_MODULE_DECL: {
            gnode_module_decl_t *declaration = (gnode_module_decl_t *)node;
            gnode_array_each(declaration->decls, {collect_annotations(val, annotations);});
            break;
        }
        default:
            break;
    }
}

static const char *annotation_node_identifier(gnode_t *node) {
    if (!node) return NULL;
    if (node->tag == NODE_VARIABLE_DECL) {
        gnode_variable_decl_t *declaration = (gnode_variable_decl_t *)node;
        if (!declaration->decls || gnode_array_size(declaration->decls) == 0) return NULL;
        return gnode_identifier(gnode_array_get(declaration->decls, 0));
    }
    return gnode_identifier(node);
}

static void internal_vm_transfer (gravity_vm *vm, gravity_object_t *obj) {
    gravity_compiler_t *compiler = (gravity_compiler_t *)gravity_vm_getdata(vm);
    marray_push(void*, *compiler->objects, obj);
}

static void internal_free_class (gravity_hash_t *hashtable, gravity_value_t key, gravity_value_t value, void *data) {
    #pragma unused (hashtable, data)

    // sanity checks
    if (!VALUE_ISA_FUNCTION(value)) return;
    if (!VALUE_ISA_STRING(key)) return;

    // check for special function
    gravity_function_t *f = VALUE_AS_FUNCTION(value);
    if (f->tag == EXEC_TYPE_SPECIAL) {
        if (f->special[0]) gravity_function_free(NULL, (gravity_function_t *)f->special[0]);
        if (f->special[1]) gravity_function_free(NULL, (gravity_function_t *)f->special[1]);
    }

    // a super special init constructor is a string that begins with $init AND it is longer than strlen($init)
    gravity_string_t *s = VALUE_AS_STRING(key);
    bool is_super_function = ((s->len > 5) && (string_casencmp(s->s, CLASS_INTERNAL_INIT_NAME, 5) == 0));
    if (!is_super_function) gravity_function_free(NULL, VALUE_AS_FUNCTION(value));
}

static void internal_vm_cleanup (gravity_vm *vm) {
    gravity_compiler_t *compiler = (gravity_compiler_t *)gravity_vm_getdata(vm);
    size_t count = marray_size(*compiler->objects);
    for (size_t i=0; i<count; ++i) {
        gravity_object_t *obj = marray_pop(*compiler->objects);
        if (OBJECT_ISA_CLASS(obj)) {
            gravity_class_t *c = (gravity_class_t *)obj;
            gravity_hash_iterate(c->htable, internal_free_class, NULL);
        }
        gravity_object_free(vm, obj);
    }
}

// MARK: -

gravity_compiler_t *gravity_compiler_create (gravity_delegate_t *delegate) {
    gravity_compiler_t *compiler = mem_alloc(NULL, sizeof(gravity_compiler_t));
    if (!compiler) return NULL;

    compiler->ast = NULL;
    compiler->objects = void_array_create();
    compiler->annotations = void_array_create();
    compiler->delegate = delegate;
    return compiler;
}

static void gravity_compiler_reset (gravity_compiler_t *compiler) {
    // free memory for array of strings storage
    if (compiler->storage) {
        cstring_array_each(compiler->storage, {mem_free((void *)val);});
        gnode_array_free(compiler->storage);
    }

    // first ast then parser, don't change the release order
    if (compiler->ast) gnode_free(compiler->ast);
    if (compiler->parser) gravity_parser_free(compiler->parser);

    // at the end free mini VM and objects array
    if (compiler->vm) {
        gravity_vm_free(compiler->vm);

        // release the core reference taken by gravity_compiler_run when the mini VM was created,
        // so that register/release stay balanced no matter how many times the compiler is run.
        // Core is really freed only when its refcount drops to zero, so a real VM created with
        // gravity_vm_new (which owns its own reference) keeps core and optionals alive.
        gravity_core_free();
    }
    if (compiler->objects) {
        marray_destroy(*compiler->objects);
        mem_free((void*)compiler->objects);
    }
    if (compiler->annotations) {
        marray_destroy(*compiler->annotations);
        mem_free(compiler->annotations);
    }

    // reset internal pointers
    compiler->vm = NULL;
    compiler->ast = NULL;
    compiler->parser = NULL;
    compiler->objects = NULL;
    compiler->annotations = NULL;
    compiler->storage = NULL;
}

void gravity_compiler_free (gravity_compiler_t *compiler) {
    gravity_compiler_reset(compiler);
    mem_free(compiler);
}

gnode_t *gravity_compiler_ast (gravity_compiler_t *compiler) {
    return compiler->ast;
}

void gravity_compiler_transfer(gravity_compiler_t *compiler, gravity_vm *vm) {
    if (!compiler->objects) return;

    // transfer each object from compiler mini VM to exec VM
    gravity_gc_setenabled(vm, false);
    size_t count = marray_size(*compiler->objects);
    for (size_t i=0; i<count; ++i) {
        gravity_object_t *obj = marray_pop(*compiler->objects);
        gravity_vm_transfer(vm, obj);
        if (!OBJECT_ISA_CLOSURE(obj)) continue;

        // $moduleinit closure needs to be explicitly initialized
        gravity_closure_t *closure = (gravity_closure_t *)obj;
        if ((closure->f->identifier) && strcmp(closure->f->identifier, INITMODULE_NAME) == 0) {
            // code is here because it does not make sense to add this overhead (that needs to be executed only once)
            // inside the gravity_vm_transfer callback which is called for each allocated object inside the VM
            gravity_vm_initmodule(vm, closure->f);
        }
    }

    gravity_gc_setenabled(vm, true);
}

// MARK: -

gravity_closure_t *gravity_compiler_run (gravity_compiler_t *compiler, const char *source, size_t len, uint32_t fileid, bool is_static, bool add_debug) {
    if ((source == NULL) || (len == 0)) return NULL;

    // CHECK cleanup first
    if (compiler->annotations) {
        marray_destroy(*compiler->annotations);
        mem_free(compiler->annotations);
        compiler->annotations = void_array_create();
    }
    if (compiler->ast) gnode_free(compiler->ast);
    if (!compiler->objects) compiler->objects = void_array_create();
    if (!compiler->annotations) compiler->annotations = void_array_create();

    // CODEGEN requires a mini vm in order to be able to handle garbage collector.
    // The mini VM is just a container for the transfer/cleanup callbacks (it holds no
    // per-compilation state) so it is created once and reused by every subsequent run
    // of the same compiler: creating a new one here would orphan the previous one and
    // would take an extra core reference that nothing releases.
    if (!compiler->vm) {
        compiler->vm = gravity_vm_newmini();
        gravity_vm_setdata(compiler->vm, (void *)compiler);
        gravity_vm_set_callbacks(compiler->vm, internal_vm_transfer, internal_vm_cleanup);

        // core reference owned by the mini VM, released by gravity_compiler_reset
        gravity_core_register(compiler->vm);
    }

    // STEP 0: CREATE PARSER
    compiler->parser = gravity_parser_create(source, len, fileid, is_static);
    if (!compiler->parser) return NULL;

    // STEP 1: SYNTAX CHECK
    compiler->ast = gravity_parser_run(compiler->parser, compiler->delegate);
    if (!compiler->ast) goto abort_compilation;
    collect_annotations(compiler->ast, compiler->annotations);
    gravity_parser_free(compiler->parser);
    compiler->parser = NULL;

    // STEP 2a: SEMANTIC CHECK (NON-LOCAL DECLARATIONS)
    bool b1 = gravity_semacheck1(compiler->ast, compiler->delegate);
    if (!b1) goto abort_compilation;

    // STEP 2b: SEMANTIC CHECK (LOCAL DECLARATIONS)
    bool b2 = gravity_semacheck2(compiler->ast, compiler->delegate);
    if (!b2) goto abort_compilation;

    // STEP 3: INTERMEDIATE CODE GENERATION (stack based VM)
	gravity_function_t *f = gravity_codegen(compiler->ast, compiler->delegate, compiler->vm, add_debug);
    if (!f) goto abort_compilation;

    // STEP 4: CODE GENERATION (register based VM)
	f = gravity_optimizer(f, add_debug);
    if (f) return gravity_closure_new(compiler->vm, f);

abort_compilation:
    gravity_compiler_reset(compiler);
    return NULL;
}

bool gravity_compiler_prepare_native(gravity_compiler_t *compiler, const char *source, size_t len, uint32_t fileid) {
    if (!compiler || !source || !len) return false;
    gravity_compiler_reset(compiler);
    compiler->objects = void_array_create();
    compiler->annotations = void_array_create();
    /* Semantic symbol tables use core String identity for hash keys. The mini
     * context is compiler-only; native output never links or executes a VM. */
    compiler->vm = gravity_vm_newmini();
    gravity_vm_setdata(compiler->vm, (void *)compiler);
    gravity_vm_set_callbacks(compiler->vm, internal_vm_transfer, internal_vm_cleanup);
    gravity_core_register(compiler->vm);
    compiler->parser = gravity_parser_create(source, len, fileid, true);
    if (!compiler->parser) return false;
    gravity_parser_set_native(compiler->parser);
    compiler->ast = gravity_parser_run(compiler->parser, compiler->delegate);
    gravity_parser_free(compiler->parser);
    compiler->parser = NULL;
    if (!compiler->ast || !gravity_semacheck1(compiler->ast, compiler->delegate) ||
        !gravity_semacheck2(compiler->ast, compiler->delegate)) return false;
    collect_annotations(compiler->ast, compiler->annotations);
    return true;
}

uint32_t gravity_compiler_annotation_count(gravity_compiler_t *compiler) {
    return (compiler && compiler->annotations) ? (uint32_t)marray_size(*compiler->annotations) : 0;
}

const gravity_annotation_t *gravity_compiler_annotation_at(gravity_compiler_t *compiler, uint32_t index) {
    if (!compiler || !compiler->annotations || index >= marray_size(*compiler->annotations)) return NULL;
    return (const gravity_annotation_t *)marray_get(*compiler->annotations, index);
}

const char *gravity_annotation_name(const gravity_annotation_t *annotation) {
    return annotation ? annotation->identifier : NULL;
}

uint32_t gravity_annotation_line(const gravity_annotation_t *annotation) { return annotation ? annotation->token.lineno : 0; }
uint32_t gravity_annotation_column(const gravity_annotation_t *annotation) { return annotation ? annotation->token.colno : 0; }
uint32_t gravity_annotation_fileid(const gravity_annotation_t *annotation) { return annotation ? annotation->token.fileid : 0; }
uint32_t gravity_annotation_target_kind(const gravity_annotation_t *annotation) {
    return (annotation && annotation->target) ? (uint32_t)((gnode_t *)annotation->target)->tag : UINT32_MAX;
}
const char *gravity_annotation_target_identifier(const gravity_annotation_t *annotation) {
    return (annotation && annotation->target) ? annotation_node_identifier((gnode_t *)annotation->target) : NULL;
}
const char *gravity_annotation_target_parent_identifier(const gravity_annotation_t *annotation) {
    if (!annotation || !annotation->target) return NULL;
    gnode_t *target = (gnode_t *)annotation->target;
    return annotation_node_identifier((gnode_t *)target->decl);
}
uint32_t gravity_annotation_argument_count(const gravity_annotation_t *annotation) {
    return (annotation && annotation->arguments) ? (uint32_t)marray_size(*annotation->arguments) : 0;
}
const char *gravity_annotation_argument_label(const gravity_annotation_t *annotation, uint32_t index) {
    if (!annotation || !annotation->arguments || index >= marray_size(*annotation->arguments)) return NULL;
    gravity_annotation_argument_t *argument = marray_get(*annotation->arguments, index);
    return argument->label;
}
const gravity_annotation_value_t *gravity_annotation_argument_value(const gravity_annotation_t *annotation, uint32_t index) {
    if (!annotation || !annotation->arguments || index >= marray_size(*annotation->arguments)) return NULL;
    gravity_annotation_argument_t *argument = marray_get(*annotation->arguments, index);
    return argument->value;
}
uint32_t gravity_annotation_value_kind_get(const gravity_annotation_value_t *value) { return value ? (uint32_t)value->kind : UINT32_MAX; }
const char *gravity_annotation_value_string(const gravity_annotation_value_t *value) {
    if (!value || ((value->kind != GRAVITY_ANNOTATION_VALUE_IDENTIFIER) && (value->kind != GRAVITY_ANNOTATION_VALUE_STRING))) return NULL;
    return value->value.string;
}
int64_t gravity_annotation_value_int(const gravity_annotation_value_t *value) { return value ? value->value.integer : 0; }
double gravity_annotation_value_float(const gravity_annotation_value_t *value) { return value ? value->value.floating : 0; }
bool gravity_annotation_value_bool(const gravity_annotation_value_t *value) { return value ? value->value.boolean : false; }
uint32_t gravity_annotation_value_count(const gravity_annotation_value_t *value) {
    return (value && value->kind == GRAVITY_ANNOTATION_VALUE_LIST && value->value.list) ? (uint32_t)marray_size(*value->value.list) : 0;
}
const gravity_annotation_value_t *gravity_annotation_value_at(const gravity_annotation_value_t *value, uint32_t index) {
    if (!value || value->kind != GRAVITY_ANNOTATION_VALUE_LIST || !value->value.list || index >= marray_size(*value->value.list)) return NULL;
    return marray_get(*value->value.list, index);
}

json_t *gravity_compiler_serialize (gravity_compiler_t *compiler, gravity_closure_t *closure) {
    #pragma unused(compiler)
    if (!closure) return NULL;

    json_t *json = json_new();
    json_begin_object(json, NULL);

    gravity_function_serialize(closure->f, json);

    json_end_object(json);
    return json;
}

bool gravity_compiler_serialize_infile (gravity_compiler_t *compiler, gravity_closure_t *closure, const char *path) {
    if (!closure) return false;
    json_t *json = gravity_compiler_serialize(compiler, closure);
    if (!json) return false;
    
    json_write_file(json, path);
    json_free(json);
    return true;
}
