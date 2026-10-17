#include "gravity_aot_internal.h"
#include "../shared/gravity_aot_runtime.h"
#include <inttypes.h>
#include <stdarg.h>

bool ga_fail(emitter *e, gnode_t *n, const char *reason) {
    if (!e->failed && e->delegate && e->delegate->error_callback) {
        error_desc_t loc = ERROR_DESC_NONE;
        if (n) loc = (error_desc_t){n->token.lineno, n->token.colno, n->token.fileid, n->token.position};
        char message[256];
        snprintf(message, sizeof(message), "AOT: %s", reason);
        e->delegate->error_callback(NULL, GRAVITY_ERROR_SEMANTIC, message, loc, e->delegate->xdata);
    }
    e->failed = true; return false;
}
void ga_put(emitter *e, const char *format, ...) {
    if (e->failed) return;
    va_list args; va_start(args, format);
    if (vfprintf(e->out, format, args) < 0) ga_fail(e, NULL, "cannot write generated C");
    va_end(args);
}
static bool identifier(const char *s) {
    if (!s || !((*s >= 'a' && *s <= 'z') || (*s >= 'A' && *s <= 'Z'))) return false;
    for (++s; *s; ++s) if (!((*s >= 'a' && *s <= 'z') || (*s >= 'A' && *s <= 'Z') ||
                            (*s >= '0' && *s <= '9') || *s == '_')) return false;
    return true;
}
static bool annotation_type(const char *s) {
    return !s || identifier(s);
}
static void guard_error(emitter *e) { ga_put(e, "if (ctx->error) goto ga_exit;\n"); }
static gnode_var_t *local(emitter *e, gnode_t *n) {
    if (!n || n->tag != NODE_IDENTIFIER_EXPR) { ga_fail(e,n,"expected a local variable"); return NULL; }
    gnode_identifier_expr_t *id=(gnode_identifier_expr_t *)n;
    if (!id->symbol || id->symbol->tag != NODE_VARIABLE || id->location.type != LOCATION_LOCAL) {
        ga_fail(e,n,"expected a local variable; captures are not supported"); return NULL;
    }
    return (gnode_var_t *)id->symbol;
}
void ga_string(emitter *e, const char *s, size_t length) {
    ga_put(e,"\"");
    for (size_t i=0; i<length; ++i) ga_put(e,"\\%03o",(unsigned char)s[i]);
    ga_put(e,"\"");
}
int ga_class_index(emitter *e, gnode_t *node) {
    for (size_t i=0; i<gnode_array_size(e->classes); ++i) if (gnode_array_get(e->classes,i)==node) return (int)i;
    return -1;
}
int ga_declaration_index(emitter *e, gnode_t *node) {
    for (size_t i=0; i<gnode_array_size(e->declarations); ++i) if (gnode_array_get(e->declarations,i)==node) return (int)i;
    return -1;
}
gnode_class_decl_t *ga_function_owner(emitter *e, gnode_function_decl_t *f) {
    for (size_t i=0; i<gnode_array_size(e->classes); ++i) {
        gnode_class_decl_t *c=(gnode_class_decl_t *)gnode_array_get(e->classes,i);
        for (size_t j=0; j<gnode_array_size(c->decls); ++j) if (gnode_array_get(c->decls,j)==(gnode_t *)f) return c;
    }
    return NULL;
}
void ga_function_name(emitter *e, gnode_function_decl_t *f) {
    /* Use declaration indices to avoid collisions between module and method names. */
    ga_put(e,"%s_fn_%d",e->prefix,ga_declaration_index(e,(gnode_t *)f));
}
static int self_field(emitter *e, const char *name) {
    if (!e->owner) return -1;
    unsigned slot=0;
    for (size_t i=0; i<gnode_array_size(e->owner->decls); ++i) {
        gnode_t *n=gnode_array_get(e->owner->decls,i); if (n->tag!=NODE_VARIABLE_DECL) continue;
        gnode_r *fields=((gnode_variable_decl_t *)n)->decls;
        for (size_t j=0; j<gnode_array_size(fields); ++j,++slot)
            if (!strcmp(((gnode_var_t *)gnode_array_get(fields,j))->identifier,name)) return (int)slot;
    }
    return -1;
}
static int binary_op(gtoken_t token) {
    switch (token) {
        case TOK_OP_ADD: return GA_ADD; case TOK_OP_SUB: return GA_SUB;
        case TOK_OP_MUL: return GA_MUL; case TOK_OP_DIV: return GA_DIV;
        case TOK_OP_REM: return GA_REM; case TOK_OP_LESS: return GA_LT;
        case TOK_OP_LESS_EQUAL: return GA_LE; case TOK_OP_GREATER: return GA_GT;
        case TOK_OP_GREATER_EQUAL: return GA_GE; case TOK_OP_ISEQUAL: return GA_EQ;
        case TOK_OP_ISNOTEQUAL: return GA_NE; case TOK_OP_AND: return GA_AND;
        case TOK_OP_OR: return GA_OR; default: return -1;
    }
}
static unsigned expr(emitter *e, gnode_t *n);
static void stmt(emitter *e, gnode_t *n);
static void assign(emitter *, gnode_t *, unsigned);
static void postfix(emitter *, gnode_postfix_expr_t *, unsigned, unsigned);
static void emit_args(emitter *, gnode_r *, unsigned);

static void emit_args(emitter *e, gnode_r *args, unsigned id) {
    size_t count=gnode_array_size(args);
    ga_put(e,"gravity_aot_value a%u[%zu]; (void)a%u;\n",id,count?count:1,id);
    for (size_t i=0; i<count; ++i) {
        unsigned value=expr(e,gnode_array_get(args,i));
        ga_put(e,"a%u[%zu]=gravity_aot_copy(ctx,t%u);\n",id,i,value); guard_error(e);
    }
}
static bool call_args(emitter *e, gnode_postfix_subexpr_t *call, unsigned id) {
    if (call->argnames) return ga_fail(e,(gnode_t *)call,"named arguments are not supported yet");
    emit_args(e,call->args,id); return !e->failed;
}
static bool compiled_function(emitter *e, gnode_t *n) {
    for (size_t i=0; i<gnode_array_size(e->functions); ++i) if (gnode_array_get(e->functions,i)==n) return true;
    return false;
}
static void postfix(emitter *e, gnode_postfix_expr_t *p, unsigned result, unsigned rhs) {
    if (p->is_await) {
        if (!e->function->is_async || rhs || gnode_array_size(p->list) != 1) {
            ga_fail(e,(gnode_t *)p,"invalid native await"); return;
        }
        gnode_postfix_subexpr_t *call = (gnode_postfix_subexpr_t *)gnode_array_get(p->list,0);
        unsigned awaited = expr(e,gnode_array_get(call->args,0)), pc = ++e->suspension;
        ga_put(e,"task->waiting=t%u; task->pc=%u;\nga_resume_%u:;\n",awaited,pc,pc);
        ga_put(e,"gravity_aot_value t%u=gravity_aot_null();\n",result);
        ga_put(e,"if (!gravity_aot_task_poll(ctx,task->waiting,&t%u)) goto ga_suspend;\n",result);
        guard_error(e);
        ga_put(e,"task->waiting=gravity_aot_null(); task->pc=0;\n");
        return;
    }
    size_t count=gnode_array_size(p->list), i=0;
    if (!count) { ga_fail(e,(gnode_t *)p,"unsupported postfix expression"); return; }
    unsigned current=0;
    gnode_identifier_expr_t *id=p->id && p->id->tag==NODE_IDENTIFIER_EXPR?(gnode_identifier_expr_t *)p->id:NULL;
    gnode_postfix_subexpr_t *first=(gnode_postfix_subexpr_t *)gnode_array_get(p->list,0);
    if (id && first->base.tag==NODE_CALL_EXPR) {
        unsigned call=++e->temporary;
        if (!call_args(e,first,call)) return;
        size_t argc=gnode_array_size(first->args);
        current=++e->temporary;
        ga_put(e,"gravity_aot_value t%u=",current);
        int ci=ga_class_index(e,id->symbol);
        if (ci>=0) ga_put(e,"gravity_aot_construct(ctx,&ga_%s_types[%d],a%u,%zu)",e->prefix,ci,call,argc);
        else if (compiled_function(e,id->symbol)) {
            gnode_function_decl_t *f=(gnode_function_decl_t *)id->symbol;
            if (argc+1!=gnode_array_size(f->params)) { ga_fail(e,(gnode_t *)p,"call argument count differs from declaration"); return; }
            gnode_class_decl_t *owner=ga_function_owner(e,f);
            if (owner && owner!=e->owner) { ga_fail(e,(gnode_t *)p,"unbound method call is not supported"); return; }
            ga_function_name(e,f); ga_put(e,"(ctx,%sa%u,%zu)",owner?"v0, ":"",call,argc);
        } else if (id->symbol && id->symbol->tag==NODE_VARIABLE && id->location.type==LOCATION_GLOBAL) {
            ga_put(e,"gravity_aot_call(ctx,gravity_aot_null(),"); ga_string(e,id->value,strlen(id->value)); ga_put(e,",a%u,%zu)",call,argc);
        } else { ga_fail(e,(gnode_t *)p,"indirect function calls are not supported yet"); return; }
        ga_put(e,";\n"); guard_error(e); i=1;
    } else current=expr(e,p->id);
    for (; i<count && !e->failed; ++i) {
        gnode_postfix_subexpr_t *step=(gnode_postfix_subexpr_t *)gnode_array_get(p->list,i);
        if (step->base.tag==NODE_ACCESS_EXPR) {
            if (!step->expr || step->expr->tag!=NODE_IDENTIFIER_EXPR) { ga_fail(e,(gnode_t *)step,"invalid member access"); return; }
            const char *key=((gnode_identifier_expr_t *)step->expr)->value;
            gnode_postfix_subexpr_t *next=i+1<count?(gnode_postfix_subexpr_t *)gnode_array_get(p->list,i+1):NULL;
            if (rhs && i+1==count) {
                ga_put(e,"(void)gravity_aot_set(ctx,t%u,",current); ga_string(e,key,strlen(key)); ga_put(e,",t%u);\n",rhs); guard_error(e); return;
            }
            unsigned value=++e->temporary;
            if (next && next->base.tag==NODE_CALL_EXPR) {
                unsigned args=++e->temporary;
                if (!call_args(e,next,args)) return;
                ga_put(e,"gravity_aot_value t%u=gravity_aot_call(ctx,t%u,",value,current); ga_string(e,key,strlen(key));
                ga_put(e,",a%u,%zu);\n",args,gnode_array_size(next->args)); ++i;
            } else {
                ga_put(e,"gravity_aot_value t%u=gravity_aot_get(ctx,t%u,",value,current); ga_string(e,key,strlen(key)); ga_put(e,");\n");
            }
            guard_error(e); current=value;
        } else if (step->base.tag==NODE_SUBSCRIPT_EXPR) {
            unsigned index=expr(e,step->expr);
            if (rhs && i+1==count) {
                ga_put(e,"gravity_aot_index_set(ctx,t%u,t%u,t%u);\n",current,index,rhs); guard_error(e); return;
            }
            unsigned value=++e->temporary;
            ga_put(e,"gravity_aot_value t%u=gravity_aot_index_get(ctx,t%u,t%u);\n",value,current,index); guard_error(e); current=value;
        } else { ga_fail(e,(gnode_t *)step,"first-class callable values are not supported yet"); return; }
    }
    if (rhs) ga_fail(e,(gnode_t *)p,"invalid assignment target");
    else ga_put(e,"gravity_aot_value t%u=t%u;\n",result,current);
}
static void assign(emitter *e, gnode_t *target, unsigned rhs) {
    if (target && target->tag==NODE_IDENTIFIER_EXPR) {
        gnode_identifier_expr_t *id=(gnode_identifier_expr_t *)target;
        if (id->location.type==LOCATION_CLASS_IVAR_SAME && e->owner) {
            int slot=self_field(e,id->value);
            if (slot<0) { ga_fail(e,target,"unknown self field"); return; }
            ga_put(e,"(void)gravity_aot_field_set(ctx,v0,%d,t%u);\n",slot,rhs); guard_error(e);
        } else {
            gnode_var_t *v=local(e,target);
            if (v) { ga_put(e,"v%u=gravity_aot_copy(ctx,t%u);\n",v->index,rhs); guard_error(e); }
        }
    } else if (target && target->tag==NODE_POSTFIX_EXPR) postfix(e,(gnode_postfix_expr_t *)target,++e->temporary,rhs);
    else ga_fail(e,target,"unsupported assignment target");
}

static unsigned expr(emitter *e, gnode_t *n) {
    unsigned t = ++e->temporary;
    if (e->failed) return t;
    if (!n) { ga_put(e, "gravity_aot_value t%u = gravity_aot_null();\n", t); return t; }
    switch (n->tag) {
        case NODE_LITERAL_EXPR: {
            gnode_literal_expr_t *v = (gnode_literal_expr_t *)n;
            if (v->type == LITERAL_INT)
                ga_put(e, "gravity_aot_value t%u = gravity_aot_int((int64_t)UINT64_C(%" PRIu64 "));\n", t, (uint64_t)v->value.n64);
            else if (v->type == LITERAL_BOOL)
                ga_put(e, "gravity_aot_value t%u = gravity_aot_bool(%d);\n", t, !!v->value.n64);
            else if (v->type == LITERAL_FLOAT) {
                if (!gravity_aot_finite(v->value.d)) { ga_fail(e,n,"non-finite numeric literals are not supported"); break; }
                ga_put(e,"gravity_aot_value t%u = gravity_aot_float(%a);\n",t,v->value.d);
            }
            else if (v->type == LITERAL_STRING) {
                ga_put(e,"gravity_aot_value t%u = gravity_aot_string(",t);
                ga_string(e,v->value.str,v->len); ga_put(e,", %u);\n",v->len);
            } else ga_fail(e,n,"interpolated strings are not supported yet");
            break;
        }
        case NODE_KEYWORD_EXPR:
            if (n->token.type == TOK_KEY_NULL) ga_put(e, "gravity_aot_value t%u = gravity_aot_null();\n", t);
            else if (n->token.type == TOK_KEY_TRUE || n->token.type == TOK_KEY_FALSE)
                ga_put(e, "gravity_aot_value t%u = gravity_aot_bool(%d);\n", t, n->token.type == TOK_KEY_TRUE);
            else ga_fail(e, n, "unsupported keyword expression");
            break;
        case NODE_IDENTIFIER_EXPR: {
            gnode_identifier_expr_t *id=(gnode_identifier_expr_t *)n;
            if (id->location.type == LOCATION_CLASS_IVAR_SAME && e->owner && id->symbol && id->symbol->tag==NODE_VARIABLE) {
                int slot=self_field(e,id->value);
                if (slot<0) { ga_fail(e,n,"unknown self field"); break; }
                ga_put(e,"gravity_aot_value t%u = gravity_aot_field_get(ctx,v0,%d);\n",t,slot); guard_error(e);
            } else if (id->location.type == LOCATION_GLOBAL && id->symbol && id->symbol->tag==NODE_VARIABLE &&
                       ((gnode_var_t *)id->symbol)->vdecl && ((gnode_var_t *)id->symbol)->vdecl->storage==TOK_KEY_EXTERN) {
                ga_put(e,"gravity_aot_value t%u = gravity_aot_get(ctx,gravity_aot_null(),",t); ga_string(e,id->value,strlen(id->value)); ga_put(e,");\n"); guard_error(e);
            } else {
                gnode_var_t *v=local(e,n); if (v) ga_put(e,"gravity_aot_value t%u = v%u;\n",t,v->index);
            }
            break;
        }
        case NODE_UNARY_EXPR: {
            gnode_unary_expr_t *u = (gnode_unary_expr_t *)n;
            if (u->op != TOK_OP_ADD && u->op != TOK_OP_SUB && u->op != TOK_OP_NOT) {
                ga_fail(e, n, "unsupported unary operator"); break;
            }
            unsigned v = expr(e, u->expr);
            if (u->op == TOK_OP_ADD) ga_put(e, "gravity_aot_value t%u = t%u;\n", t, v);
            else ga_put(e, "gravity_aot_value t%u = gravity_aot_unary(ctx, %d, t%u);\n", t, u->op == TOK_OP_SUB ? GA_NEG : GA_NOT, v);
            guard_error(e); break;
        }
        case NODE_BINARY_EXPR: {
            gnode_binary_expr_t *b = (gnode_binary_expr_t *)n;
            if (b->op == TOK_OP_ASSIGN) {
                /* Gravity evaluates the RHS before resolving the assignment target. */
                unsigned right=expr(e,b->right);
                assign(e,b->left,right);
                ga_put(e,"gravity_aot_value t%u = t%u;\n",t,right); break;
            }
            if (b->op == TOK_OP_RANGE_INCLUDED || b->op == TOK_OP_RANGE_EXCLUDED) {
                unsigned left=expr(e,b->left), right=expr(e,b->right);
                ga_put(e,"gravity_aot_value t%u = gravity_aot_range_new(ctx,t%u,t%u,%u);\n",t,left,right,b->op==TOK_OP_RANGE_INCLUDED);
                guard_error(e); break;
            }
            int op = binary_op(b->op);
            if (op < 0) { ga_fail(e, n, "unsupported binary operator"); break; }
            /* Materialize operands in source order; C call argument order is unspecified. */
            unsigned left = expr(e, b->left), right = expr(e, b->right);
            ga_put(e, "gravity_aot_value t%u = gravity_aot_binary(ctx, %d, t%u, t%u);\n", t, op, left, right);
            guard_error(e); break;
        }
        case NODE_POSTFIX_EXPR: postfix(e,(gnode_postfix_expr_t *)n,t,0); break;
        case NODE_LIST_EXPR: {
            gnode_list_expr_t *l=(gnode_list_expr_t *)n;
            if (l->ismap) { ga_fail(e,n,"maps are not supported yet"); break; }
            emit_args(e,l->list1,t);
            ga_put(e,"gravity_aot_value t%u = gravity_aot_list_new(ctx,a%u,%zu);\n",t,t,gnode_array_size(l->list1)); guard_error(e); break;
        }
        default: ga_fail(e, n, "unsupported expression (closures and maps require a later backend stage)");
    }
    ga_put(e, "(void)t%u;\n", t);
    return t;
}

static void stmt(emitter *e, gnode_t *n) {
    if (!n || e->failed) return;
    switch (n->tag) {
        case NODE_COMPOUND_STAT: case NODE_LIST_STAT: {
            gnode_compound_stmt_t *b = (gnode_compound_stmt_t *)n;
            ga_put(e, "{\n");
            for (size_t i = 0; i < gnode_array_size(b->stmts); ++i) stmt(e, gnode_array_get(b->stmts, i));
            ga_put(e, "}\n"); break;
        }
        case NODE_VARIABLE_DECL: {
            gnode_variable_decl_t *d = (gnode_variable_decl_t *)n;
            if (gnode_array_size(d->base.annotations)) { ga_fail(e,n,"local declaration attributes are not supported yet"); break; }
            for (size_t i = 0; i < gnode_array_size(d->decls); ++i) {
                gnode_var_t *v = (gnode_var_t *)gnode_array_get(d->decls, i);
                if (!annotation_type(v->annotation_type) || v->iscomputed || v->upvalue) {
                    ga_fail(e, (gnode_t *)v, "computed properties and captured locals are not supported yet"); break;
                }
                unsigned value = expr(e, v->expr);
                ga_put(e, "gravity_aot_value v%u = gravity_aot_copy(ctx,t%u); (void)v%u;\n", v->index, value, v->index); guard_error(e);
            }
            break;
        }
        case NODE_FLOW_STAT: {
            gnode_flow_stmt_t *f = (gnode_flow_stmt_t *)n;
            if (n->token.type != TOK_KEY_IF) { ga_fail(e, n, "only if/else flow is supported yet"); break; }
            unsigned c = expr(e, f->cond);
            ga_put(e, "if (gravity_aot_truth(ctx, t%u)) {\n", c); stmt(e, f->stmt); ga_put(e, "}\n");
            if (f->elsestmt) { ga_put(e, "else {\n"); stmt(e, f->elsestmt); ga_put(e, "}\n"); }
            guard_error(e); break;
        }
        case NODE_LOOP_STAT: {
            gnode_loop_stmt_t *l = (gnode_loop_stmt_t *)n;
            if (n->token.type == TOK_KEY_FOR) {
                unsigned iterable=expr(e,l->expr), seq=++e->temporary;
                if (!l->cond || l->cond->tag != NODE_VARIABLE_DECL || gnode_array_size(((gnode_variable_decl_t *)l->cond)->decls)!=1) {
                    ga_fail(e,n,"for requires a single declared loop variable"); break;
                }
                gnode_var_t *v=(gnode_var_t *)gnode_array_get(((gnode_variable_decl_t *)l->cond)->decls,0);
                ga_put(e,"{ uint64_t state%u=0; gravity_aot_value v%u=gravity_aot_null(); (void)v%u;\nwhile (1) {\n",seq,v->index,v->index);
                ga_put(e,"if (!gravity_aot_tick(ctx)) goto ga_exit;\nint next%u=gravity_aot_next(ctx,t%u,&state%u,&v%u);\n",seq,iterable,seq,v->index);
                guard_error(e); ga_put(e,"if (!next%u) break;\n",seq);
                ga_put(e,"v%u=gravity_aot_copy(ctx,v%u);\n",v->index,v->index); guard_error(e);
                ++e->loop_depth; stmt(e,l->stmt); --e->loop_depth; ga_put(e,"} }\n"); break;
            }
            if (n->token.type != TOK_KEY_WHILE) { ga_fail(e,n,"repeat loops are not supported yet"); break; }
            ga_put(e, "while (1) {\nif (!gravity_aot_tick(ctx)) goto ga_exit;\n");
            unsigned c = expr(e, l->cond);
            ga_put(e, "if (!gravity_aot_truth(ctx, t%u)) break;\n", c); guard_error(e);
            ++e->loop_depth; stmt(e, l->stmt); --e->loop_depth;
            ga_put(e, "}\n"); break;
        }
        case NODE_JUMP_STAT: {
            gnode_jump_stmt_t *j = (gnode_jump_stmt_t *)n;
            if (n->token.type == TOK_KEY_RETURN) {
                unsigned v = expr(e, j->expr); ga_put(e, "result = t%u; goto ga_exit;\n", v);
            } else if (e->loop_depth && (n->token.type == TOK_KEY_BREAK || n->token.type == TOK_KEY_CONTINUE))
                ga_put(e, "%s;\n", n->token.type == TOK_KEY_BREAK ? "break" : "continue");
            else ga_fail(e, n, "unsupported jump statement");
            break;
        }
        case NODE_EMPTY_STAT: break;
        default: (void)expr(e, n); break;
    }
}

static bool add_function(emitter *e, gnode_function_decl_t *f) {
    if (!identifier(f->identifier) || !f->block || f->is_closure || f->has_defaults ||
        gnode_array_size(f->uplist) || f->storage==TOK_KEY_EXTERN || f->storage==TOK_KEY_STATIC)
        return ga_fail(e,(gnode_t *)f,"static/extern methods, captures and default arguments are not supported yet");
    gnode_array_push(e->functions,(gnode_t *)f); gnode_array_push(e->declarations,(gnode_t *)f); return true;
}
static bool collect(emitter *e, gnode_t *ast) {
    if (!ast || ast->tag!=NODE_LIST_STAT) return ga_fail(e,ast,"expected a module AST");
    gnode_r *nodes=((gnode_list_stmt_t *)ast)->stmts;
    for (size_t i=0; i<gnode_array_size(nodes); ++i) {
        gnode_t *n=gnode_array_get(nodes,i);
        if (n->tag==NODE_EMPTY_STAT) continue;
        if (n->tag==NODE_VARIABLE_DECL && ((gnode_variable_decl_t *)n)->storage==TOK_KEY_EXTERN) continue;
        if (n->tag==NODE_FUNCTION_DECL) { if (!add_function(e,(gnode_function_decl_t *)n)) return false; continue; }
        if (n->tag!=NODE_CLASS_DECL) return ga_fail(e,n,"only functions, classes/structs and extern bindings are supported at module scope");
        gnode_class_decl_t *c=(gnode_class_decl_t *)n;
        if (c->storage==TOK_KEY_EXTERN) continue;
        if (!identifier(c->identifier) || c->superclass || c->storage==TOK_KEY_STATIC || gnode_array_size(c->protocols))
            return ga_fail(e,n,"inheritance, static classes and protocols are not supported yet");
        gnode_array_push(e->classes,n); gnode_array_push(e->declarations,n);
        for (size_t j=0; j<gnode_array_size(c->decls); ++j) {
            gnode_t *member=gnode_array_get(c->decls,j);
            if (member->tag==NODE_FUNCTION_DECL) { if (!add_function(e,(gnode_function_decl_t *)member)) return false; }
            else if (member->tag==NODE_VARIABLE_DECL) {
                gnode_variable_decl_t *d=(gnode_variable_decl_t *)member;
                if (d->storage==TOK_KEY_STATIC || d->storage==TOK_KEY_EXTERN) return ga_fail(e,member,"static/extern fields are not supported yet");
                for (size_t k=0; k<gnode_array_size(d->decls); ++k) {
                    gnode_var_t *v=(gnode_var_t *)gnode_array_get(d->decls,k);
                    if (v->iscomputed || v->upvalue) return ga_fail(e,(gnode_t *)v,"computed/captured fields are not supported yet");
                    gnode_array_push(e->declarations,(gnode_t *)v);
                }
            } else return ga_fail(e,member,"nested classes and enums are not supported yet");
        }
    }
    if (!gnode_array_size(e->functions) && !gnode_array_size(e->classes)) return ga_fail(e,ast,"module has no declarations");
    return true;
}
/* Spill compiler-generated locals, expression temporaries, argument arrays and
 * iteration cursors to a persistent task frame. Only generated C is scanned;
 * user strings are octal escaped by ga_string. */
static bool frame_token(const char *s, size_t *length, char *kind, unsigned *index) {
    const char *p=s;
    if (!strncmp(p,"state",5)) { *kind='s'; p+=5; }
    else if (*p=='v' || *p=='t' || *p=='a') { *kind=*p++; }
    else return false;
    if (*p<'0' || *p>'9') return false;
    *index=0;
    while (*p>='0' && *p<='9') { *index=*index*10+(unsigned)(*p-'0'); ++p; }
    if ((*p>='a' && *p<='z') || (*p>='A' && *p<='Z') || *p=='_') return false;
    *length=(size_t)(p-s); return true;
}
static void coroutine(emitter *e, gnode_function_decl_t *f) {
    FILE *output=e->out, *body=tmpfile();
    if (!body) { ga_fail(e,(gnode_t *)f,"cannot stage coroutine"); return; }
    e->out=body;
    stmt(e,(gnode_t *)f->block);
    fflush(body); long size=ftell(body); rewind(body);
    char *code=size>=0?malloc((size_t)size+1):NULL;
    if (!code || fread(code,1,(size_t)size,body)!=(size_t)size) ga_fail(e,(gnode_t *)f,"cannot read coroutine staging stream");
    fclose(body); e->out=output;
    if (e->failed) { free(code); return; }
    code[size]=0;
    unsigned locals=(unsigned)f->nlocals+(unsigned)gnode_array_size(f->params)+1;
    unsigned slots=locals+e->temporary+1;
    unsigned *arrays=calloc(e->temporary+1,sizeof(unsigned));
    if (!arrays) { free(code); ga_fail(e,(gnode_t *)f,"cannot allocate coroutine layout"); return; }
    for (const char *p=code; (p=strstr(p,"gravity_aot_value a")); ++p) {
        unsigned id=0,count=0;
        if (sscanf(p,"gravity_aot_value a%u[%u]",&id,&count)==2 && id<=e->temporary) { arrays[id]=slots; slots+=count; }
    }
    int fi=ga_declaration_index(e,(gnode_t *)f);
    ga_put(e,"static void %s_resume_%d(gravity_aot_context *ctx, gravity_aot_task *task) {\n",e->prefix,fi);
    ga_put(e,"gravity_aot_value result=gravity_aot_null();\nswitch (task->pc) {\ncase 0: break;\n");
    for (unsigned i=1;i<=e->suspension;++i) ga_put(e,"case %u: goto ga_resume_%u;\n",i,i);
    ga_put(e,"default: gravity_aot_error(ctx,GRAVITY_AOT_TYPE); goto ga_exit;\n}\n");
    for (const char *p=code; *p;) {
        if (!strncmp(p,"gravity_aot_value ",18) || !strncmp(p,"uint64_t state",14)) {
            const char *value=p+(!strncmp(p,"gravity_aot_value ",18)?18:9);
            size_t len=0; char kind=0; unsigned id=0;
            if (frame_token(value,&len,&kind,&id)) {
                p=value;
                if (kind=='a') { const char *end=strchr(p,';'); if (end) p=end+1; }
                continue;
            }
        }
        if ((*p>='a' && *p<='z') || (*p>='A' && *p<='Z') || *p=='_') {
            size_t len=0; char kind=0; unsigned id=0;
            if (frame_token(p,&len,&kind,&id)) {
                if (kind=='a') ga_put(e,"(&task->values[%u])",arrays[id]);
                else if (kind=='s') ga_put(e,"task->cursors[%u]",id);
                else ga_put(e,"task->values[%u]",kind=='v'?id:locals+id);
                p+=len;
            } else {
                const char *start=p++;
                while ((*p>='a' && *p<='z') || (*p>='A' && *p<='Z') || (*p>='0' && *p<='9') || *p=='_') ++p;
                ga_put(e,"%.*s",(int)(p-start),start);
            }
        } else { ga_put(e,"%c",*p); ++p; }
    }
    ga_put(e,"goto ga_exit;\nga_exit: task->result=result; task->error=ctx->error; task->state=ctx->error?GA_TASK_FAILED:GA_TASK_COMPLETE;\nreturn;\n");
    if (e->suspension) ga_put(e,"ga_suspend: if (ctx->error) { task->error=ctx->error; task->state=GA_TASK_FAILED; } else task->state=GA_TASK_PENDING;\n");
    ga_put(e,"}\n");
    ga_put(e,"static gravity_aot_value "); ga_function_name(e,f);
    ga_put(e,"(gravity_aot_context *ctx,%sconst gravity_aot_value *args,uint32_t argc) {\n",e->owner?"gravity_aot_value receiver, ":"");
    ga_put(e,"if (!ctx) return gravity_aot_null();\nif (argc!=%zu || (argc && !args)) { gravity_aot_error(ctx,GRAVITY_AOT_ARITY); return gravity_aot_null(); }\n",gnode_array_size(f->params)-1);
    ga_put(e,"gravity_aot_value value=gravity_aot_task_new(ctx,%s_resume_%d,%u,%u);\nif (ctx->error) return gravity_aot_null();\ngravity_aot_task *task=value.task; (void)task;\n",e->prefix,fi,slots,e->temporary+1);
    if (e->owner) ga_put(e,"task->values[0]=receiver;\nif (receiver.kind!=GRAVITY_AOT_OBJECT || !receiver.object || receiver.object->type!=&ga_%s_types[%d]) { gravity_aot_error(ctx,GRAVITY_AOT_TYPE); return gravity_aot_null(); }\n",e->prefix,ga_class_index(e,(gnode_t *)e->owner));
    for (size_t p=1;p<gnode_array_size(f->params);++p) {
        gnode_var_t *v=(gnode_var_t *)gnode_array_get(f->params,p);
        ga_put(e,"task->values[%u]=gravity_aot_copy(ctx,args[%zu]);\n",v->index,p-1);
        if (v->annotation_type) { ga_put(e,"if (!gravity_aot_matches(ctx,task->values[%u],",v->index); ga_string(e,v->annotation_type,strlen(v->annotation_type)); ga_put(e,")) return gravity_aot_null();\n"); }
    }
    ga_put(e,"return ctx->error?gravity_aot_null():value;\n}\n");
    free(arrays); free(code);
}

static bool generate(emitter *e, gnode_t *ast) {
    if (!identifier(e->prefix)) return ga_fail(e,NULL,"module prefix must be an ASCII identifier starting with a letter");
    if (!collect(e,ast)) return false;
    ga_put(e,"/* Generated by Gravity AOT; standalone ABI 3. */\n#include \"gravity_aot_runtime.h\"\n");
    if (gnode_array_size(e->classes)) ga_put(e,"static const gravity_aot_class ga_%s_types[%zu];\n",e->prefix,gnode_array_size(e->classes));
    for (size_t i=0; i<gnode_array_size(e->functions); ++i) {
        gnode_function_decl_t *f=(gnode_function_decl_t *)gnode_array_get(e->functions,i);
        ga_put(e,"static gravity_aot_value "); ga_function_name(e,f);
        ga_put(e,"(gravity_aot_context *, %sconst gravity_aot_value *, uint32_t);\n",ga_function_owner(e,f)?"gravity_aot_value, ":"");
    }
    for (size_t i=0;i<gnode_array_size(e->classes);++i) {
        e->owner=(gnode_class_decl_t *)gnode_array_get(e->classes,i);
        e->function=NULL;
        for (size_t j=0;j<gnode_array_size(e->owner->decls);++j) {
            gnode_t *member=gnode_array_get(e->owner->decls,j);
            if (member->tag!=NODE_VARIABLE_DECL) continue;
            gnode_r *fields=((gnode_variable_decl_t *)member)->decls;
            for (size_t k=0;k<gnode_array_size(fields);++k) {
                gnode_var_t *v=(gnode_var_t *)gnode_array_get(fields,k);
                if (ga_constant_default(v->expr)) continue;
                e->temporary=0;
                ga_put(e,"static gravity_aot_value %s_field_%d(gravity_aot_context *ctx,gravity_aot_value v0) {\n(void)v0;\ngravity_aot_value result=gravity_aot_null();\n",e->prefix,ga_declaration_index(e,(gnode_t *)v));
                unsigned value=expr(e,v->expr);
                ga_put(e,"result=t%u; goto ga_exit;\nga_exit: return ctx->error?gravity_aot_null():result;\n}\n",value);
            }
        }
    }
    for (size_t i=0; i<gnode_array_size(e->functions); ++i) {
        gnode_function_decl_t *f=(gnode_function_decl_t *)gnode_array_get(e->functions,i);
        e->function=f; e->owner=ga_function_owner(e,f); e->temporary=0; e->suspension=0;
        if (f->is_async) { coroutine(e,f); continue; }
        size_t arity=gnode_array_size(f->params)-1;
        ga_put(e,"static gravity_aot_value "); ga_function_name(e,f);
        ga_put(e,"(gravity_aot_context *ctx, %sconst gravity_aot_value *args, uint32_t argc) {\n",e->owner?"gravity_aot_value receiver, ":"");
        ga_put(e,"gravity_aot_value result=gravity_aot_null(); if (!ctx) return result;\n");
        ga_put(e,"if (ctx->abi_version!=GRAVITY_AOT_ABI_VERSION) { gravity_aot_error(ctx,GRAVITY_AOT_BAD_ABI); return result; }\n");
        ga_put(e,"if (argc!=%zu || (argc && !args)) { gravity_aot_error(ctx,GRAVITY_AOT_ARITY); return result; }\n",arity);
        ga_put(e,"if (ctx->depth>=ctx->max_depth || !gravity_aot_tick(ctx)) { gravity_aot_error(ctx,GRAVITY_AOT_LIMIT); return result; }\n++ctx->depth;\n");
        if (e->owner) {
            ga_put(e,"gravity_aot_value v0=receiver; (void)v0;\nif (receiver.kind!=GRAVITY_AOT_OBJECT || !receiver.object || receiver.object->type!=&ga_%s_types[%d]) { gravity_aot_error(ctx,GRAVITY_AOT_TYPE); goto ga_exit; }\n",e->prefix,ga_class_index(e,(gnode_t *)e->owner));
        }
        for (size_t p=1; p<gnode_array_size(f->params); ++p) {
            gnode_var_t *v=(gnode_var_t *)gnode_array_get(f->params,p);
            ga_put(e,"gravity_aot_value v%u=gravity_aot_copy(ctx,args[%zu]); (void)v%u;\n",v->index,p-1,v->index); guard_error(e);
            if (v->annotation_type) {
                ga_put(e,"if (!gravity_aot_matches(ctx,v%u,",v->index); ga_string(e,v->annotation_type,strlen(v->annotation_type));
                ga_put(e,")) goto ga_exit;\n");
            }
        }
        stmt(e,(gnode_t *)f->block);
        ga_put(e,"goto ga_exit;\nga_exit:\n--ctx->depth;\nreturn ctx->error?gravity_aot_null():result;\n}\n");
    }
    ga_metadata(e); return !e->failed;
}

bool gravity_compiler_emit_c(gravity_compiler_t *compiler, FILE *output, const char *prefix, gravity_delegate_t *delegate) {
    emitter e = {.delegate = delegate, .prefix = prefix};
    if (!compiler || !output) return ga_fail(&e, NULL, "missing compiler or output stream");
    e.out = tmpfile();
    if (!e.out) return ga_fail(&e, NULL, "cannot create staging stream");
    e.functions=gnode_array_create(); e.classes=gnode_array_create(); e.declarations=gnode_array_create();
    bool ok = generate(&e, gravity_compiler_ast(compiler));
    if (e.functions) gnode_array_free(e.functions);
    if (e.classes) gnode_array_free(e.classes);
    if (e.declarations) gnode_array_free(e.declarations);
    if (ok && fflush(e.out) != 0) ok = ga_fail(&e, NULL, "cannot flush staging stream");
    if (ok) {
        rewind(e.out);
        char bytes[4096]; size_t count;
        while ((count = fread(bytes, 1, sizeof(bytes), e.out)))
            if (fwrite(bytes, 1, count, output) != count) { ok = ga_fail(&e, NULL, "cannot write output stream"); break; }
        if (ferror(e.out)) ok = ga_fail(&e, NULL, "cannot read staging stream");
    }
    fclose(e.out); return ok;
}
