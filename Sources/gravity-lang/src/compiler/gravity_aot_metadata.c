#include "gravity_aot_internal.h"
#include <inttypes.h>

static void text(emitter *e, const char *s) { if (s) ga_string(e,s,strlen(s)); else ga_put(e,"NULL"); }
static unsigned attribute_value(emitter *e, gravity_annotation_value_t *v) {
    unsigned id=++e->metadata_serial;
    size_t count=v->kind==GRAVITY_ANNOTATION_VALUE_LIST?gnode_array_size(v->value.list):0;
    if (count) {
        unsigned *ids=mem_alloc(NULL,count*sizeof(unsigned));
        if (!ids) { ga_fail(e,NULL,"cannot allocate attribute staging"); return id; }
        for (size_t i=0; i<count; ++i) ids[i]=attribute_value(e,(gravity_annotation_value_t *)gnode_array_get(v->value.list,i));
        ga_put(e,"static const gravity_aot_attribute_value *const ga_attr_items_%u[] = {",id);
        for (size_t i=0; i<count; ++i) ga_put(e,"&ga_attr_value_%u,",ids[i]);
        ga_put(e,"};\n"); mem_free(ids);
    }
    ga_put(e,"static const gravity_aot_attribute_value ga_attr_value_%u = {.kind=%u,.count=%zu,",id,v->kind,count);
    switch (v->kind) {
        case GRAVITY_ANNOTATION_VALUE_IDENTIFIER: case GRAVITY_ANNOTATION_VALUE_STRING:
            ga_put(e,".text="); text(e,v->value.string); break;
        case GRAVITY_ANNOTATION_VALUE_INT: ga_put(e,".integer=(int64_t)UINT64_C(%" PRIu64 ")",(uint64_t)v->value.integer); break;
        case GRAVITY_ANNOTATION_VALUE_FLOAT:
            if (!gravity_aot_finite(v->value.floating)) ga_fail(e,NULL,"non-finite attribute values are not supported");
            else ga_put(e,".floating=%a",v->value.floating); break;
        case GRAVITY_ANNOTATION_VALUE_BOOL: ga_put(e,".integer=%u",v->value.boolean); break;
        case GRAVITY_ANNOTATION_VALUE_LIST: if (count) ga_put(e,".items=ga_attr_items_%u",id); else ga_put(e,".items=NULL"); break;
        case GRAVITY_ANNOTATION_VALUE_NULL: ga_put(e,".text=NULL"); break;
    }
    ga_put(e,"};\n"); return id;
}
static gravity_annotation_r *attributes(gnode_t *node) {
    if (node->tag==NODE_VARIABLE) return ((gnode_var_t *)node)->vdecl->base.annotations;
    return node->annotations;
}
static void declaration_attributes(emitter *e, gnode_t *node, size_t decl) {
    gravity_annotation_r *attrs=attributes(node);
    size_t count=gnode_array_size(attrs);
    for (size_t i=0; i<count; ++i) {
        gravity_annotation_t *a=(gravity_annotation_t *)gnode_array_get(attrs,i);
        size_t argc=gnode_array_size(a->arguments);
        if (!argc) continue;
        unsigned *ids=mem_alloc(NULL,argc*sizeof(unsigned));
        if (!ids) { ga_fail(e,node,"cannot allocate annotation arguments"); return; }
        for (size_t j=0; j<argc; ++j) {
            gravity_annotation_argument_t *arg=(gravity_annotation_argument_t *)gnode_array_get(a->arguments,j);
            ids[j]=attribute_value(e,arg->value);
        }
        ga_put(e,"static const gravity_aot_attribute_argument ga_args_%zu_%zu[] = {\n",decl,i);
        for (size_t j=0; j<argc; ++j) {
            gravity_annotation_argument_t *arg=(gravity_annotation_argument_t *)gnode_array_get(a->arguments,j);
            ga_put(e,"{"); text(e,arg->label); ga_put(e,",&ga_attr_value_%u},\n",ids[j]);
        }
        ga_put(e,"};\n"); mem_free(ids);
    }
    if (node->tag==NODE_FUNCTION_DECL) {
        gnode_function_decl_t *f=(gnode_function_decl_t *)node;
        if (gnode_array_size(f->params)>1) {
            ga_put(e,"static const gravity_aot_parameter ga_params_%zu[] = {\n",decl);
            for (size_t p=1; p<gnode_array_size(f->params); ++p) {
                gnode_var_t *v=(gnode_var_t *)gnode_array_get(f->params,p);
                ga_put(e,"{"); text(e,v->identifier); ga_put(e,","); text(e,v->annotation_type); ga_put(e,"},\n");
            }
            ga_put(e,"};\n");
        }
    }
    if (!count) return;
    ga_put(e,"static const gravity_aot_attribute ga_attrs_%zu[] = {\n",decl);
    for (size_t i=0; i<count; ++i) {
        gravity_annotation_t *a=(gravity_annotation_t *)gnode_array_get(attrs,i);
        size_t argc=gnode_array_size(a->arguments);
        ga_put(e,"{"); text(e,a->identifier);
        ga_put(e,",%zu,%u,%u,%u,",argc,a->token.fileid,a->token.lineno,a->token.colno);
        if (argc) ga_put(e,"ga_args_%zu_%zu",decl,i); else ga_put(e,"NULL");
        ga_put(e,"},\n");
    }
    ga_put(e,"};\n");
}
static gnode_class_decl_t *field_owner(emitter *e, gnode_t *v) {
    for (size_t i=0; i<gnode_array_size(e->classes); ++i) {
        gnode_class_decl_t *c=(gnode_class_decl_t *)gnode_array_get(e->classes,i);
        for (size_t j=0; j<gnode_array_size(c->decls); ++j) {
            gnode_t *n=gnode_array_get(c->decls,j); if (n->tag!=NODE_VARIABLE_DECL) continue;
            gnode_r *vars=((gnode_variable_decl_t *)n)->decls;
            for (size_t k=0; k<gnode_array_size(vars); ++k) if (gnode_array_get(vars,k)==v) return c;
        }
    }
    return NULL;
}
bool ga_constant_default(gnode_t *n) {
    if (!n || n->tag==NODE_KEYWORD_EXPR) return true;
    if (n->tag==NODE_LITERAL_EXPR) return ((gnode_literal_expr_t *)n)->type!=LITERAL_STRING_INTERPOLATED;
    if (n->tag==NODE_UNARY_EXPR) return ga_constant_default(((gnode_unary_expr_t *)n)->expr);
    return false;
}
static bool default_value(emitter *e, gnode_t *n, bool negative) {
    if (!n || (n->tag==NODE_KEYWORD_EXPR && n->token.type==TOK_KEY_NULL)) { ga_put(e,"{0}"); return true; }
    if (n->tag==NODE_UNARY_EXPR) {
        gnode_unary_expr_t *u=(gnode_unary_expr_t *)n;
        if (u->op==TOK_OP_SUB || u->op==TOK_OP_ADD) return default_value(e,u->expr,u->op==TOK_OP_SUB?!negative:negative);
    }
    if (n->tag==NODE_KEYWORD_EXPR && (n->token.type==TOK_KEY_TRUE || n->token.type==TOK_KEY_FALSE)) {
        if (negative) ga_put(e,"{.integer=%d,.kind=GRAVITY_AOT_INT}",n->token.type==TOK_KEY_TRUE?-1:0);
        else ga_put(e,"{.integer=%u,.kind=GRAVITY_AOT_BOOL}",n->token.type==TOK_KEY_TRUE); return true;
    }
    if (n->tag==NODE_LITERAL_EXPR) {
        gnode_literal_expr_t *v=(gnode_literal_expr_t *)n;
        if (v->type==LITERAL_INT || v->type==LITERAL_BOOL) {
            uint64_t number=(uint64_t)v->value.n64; if (negative) number=UINT64_C(0)-number;
            ga_put(e,"{.integer=(int64_t)UINT64_C(%" PRIu64 "),.kind=%u}",number,v->type==LITERAL_BOOL&&!negative?GRAVITY_AOT_BOOL:GRAVITY_AOT_INT); return true;
        }
        if (v->type==LITERAL_FLOAT) { if (!gravity_aot_finite(v->value.d)) return ga_fail(e,n,"non-finite field defaults are not supported"); ga_put(e,"{.floating=%a,.kind=GRAVITY_AOT_FLOAT}",negative?-v->value.d:v->value.d); return true; }
        if (v->type==LITERAL_STRING && !negative) {
            ga_put(e,"{.string="); ga_string(e,v->value.str,v->len); ga_put(e,",.kind=GRAVITY_AOT_STRING,.length=%u}",v->len); return true;
        }
    }
    return ga_fail(e,n,"stored field defaults must be scalar/string constants or null");
}
void ga_metadata(emitter *e) {
    size_t declarations=gnode_array_size(e->declarations), classes=gnode_array_size(e->classes), exports=0;
    for (size_t i=0; i<declarations; ++i) declaration_attributes(e,gnode_array_get(e->declarations,i),i);
    ga_put(e,"static const gravity_aot_declaration ga_%s_declarations[] = {\n",e->prefix);
    for (size_t i=0; i<declarations; ++i) {
        gnode_t *n=gnode_array_get(e->declarations,i);
        gnode_class_decl_t *parent=n->tag==NODE_VARIABLE?field_owner(e,n):n->tag==NODE_FUNCTION_DECL?ga_function_owner(e,(gnode_function_decl_t *)n):NULL;
        unsigned kind=n->tag==NODE_VARIABLE?GRAVITY_AOT_DECL_FIELD:n->tag==NODE_CLASS_DECL?
            (((gnode_class_decl_t *)n)->is_struct?GRAVITY_AOT_DECL_STRUCT:GRAVITY_AOT_DECL_CLASS):
            parent?GRAVITY_AOT_DECL_METHOD:GRAVITY_AOT_DECL_FUNCTION;
        ga_put(e,"{"); text(e,gnode_identifier(n)); ga_put(e,","); text(e,parent?parent->identifier:NULL); ga_put(e,",");
        text(e,n->tag==NODE_VARIABLE?((gnode_var_t *)n)->annotation_type:NULL);
        size_t count=gnode_array_size(attributes(n));
        ga_put(e,",%u,%u,%u,%u,%zu,",kind,n->token.fileid,n->token.lineno,n->token.colno,count);
        if (count) ga_put(e,"ga_attrs_%zu",i); else ga_put(e,"NULL");
        size_t params=n->tag==NODE_FUNCTION_DECL?gnode_array_size(((gnode_function_decl_t *)n)->params)-1:0;
        ga_put(e,",%zu,",params);
        if (params) ga_put(e,"ga_params_%zu",i); else ga_put(e,"NULL"); ga_put(e,"},\n");
    }
    ga_put(e,"};\n");
    for (size_t i=0; i<classes; ++i) {
        gnode_class_decl_t *c=(gnode_class_decl_t *)gnode_array_get(e->classes,i);
        size_t fields=0, methods=0;
        for (size_t j=0; j<gnode_array_size(c->decls); ++j) {
            gnode_t *n=gnode_array_get(c->decls,j);
            if (n->tag==NODE_VARIABLE_DECL) fields+=gnode_array_size(((gnode_variable_decl_t *)n)->decls);
            if (n->tag==NODE_FUNCTION_DECL) ++methods;
        }
        if (fields) {
            ga_put(e,"static const gravity_aot_field ga_fields_%zu[] = {\n",i);
            for (size_t j=0; j<gnode_array_size(c->decls); ++j) {
                gnode_t *n=gnode_array_get(c->decls,j); if (n->tag!=NODE_VARIABLE_DECL) continue;
                gnode_variable_decl_t *d=(gnode_variable_decl_t *)n;
                for (size_t k=0; k<gnode_array_size(d->decls); ++k) {
                    gnode_var_t *v=(gnode_var_t *)gnode_array_get(d->decls,k);
                    ga_put(e,"{&ga_%s_declarations[%d],",e->prefix,ga_declaration_index(e,(gnode_t *)v));
                    if (ga_constant_default(v->expr)) default_value(e,v->expr,false); else ga_put(e,"{0}");
                    ga_put(e,",%u,",d->type==TOK_KEY_CONST);
                    if (ga_constant_default(v->expr)) ga_put(e,"NULL");
                    else ga_put(e,"%s_field_%d",e->prefix,ga_declaration_index(e,(gnode_t *)v));
                    ga_put(e,"},\n");
                }
            }
            ga_put(e,"};\n");
        }
        if (methods) {
            ga_put(e,"static const gravity_aot_method_export ga_methods_%zu[] = {\n",i);
            for (size_t j=0; j<gnode_array_size(c->decls); ++j) {
                gnode_t *n=gnode_array_get(c->decls,j); if (n->tag!=NODE_FUNCTION_DECL) continue;
                gnode_function_decl_t *f=(gnode_function_decl_t *)n;
                ga_put(e,"{"); text(e,f->identifier); ga_put(e,",%zu,",gnode_array_size(f->params)-1); ga_function_name(e,f);
                ga_put(e,",&ga_%s_declarations[%d]},\n",e->prefix,ga_declaration_index(e,n));
            }
            ga_put(e,"};\n");
        }
    }
    if (classes) {
        ga_put(e,"static const gravity_aot_class ga_%s_types[%zu] = {\n",e->prefix,classes);
        for (size_t i=0; i<classes; ++i) {
            gnode_class_decl_t *c=(gnode_class_decl_t *)gnode_array_get(e->classes,i);
            size_t fields=0,methods=0;
            for (size_t j=0; j<gnode_array_size(c->decls); ++j) {
                gnode_t *n=gnode_array_get(c->decls,j);
                if (n->tag==NODE_VARIABLE_DECL) fields+=gnode_array_size(((gnode_variable_decl_t *)n)->decls);
                if (n->tag==NODE_FUNCTION_DECL) ++methods;
            }
            ga_put(e,"{&ga_%s_declarations[%d],%u,%zu,%zu,",e->prefix,ga_declaration_index(e,(gnode_t *)c),c->is_struct,fields,methods);
            if (fields) ga_put(e,"ga_fields_%zu",i); else ga_put(e,"NULL"); ga_put(e,",");
            if (methods) ga_put(e,"ga_methods_%zu",i); else ga_put(e,"NULL"); ga_put(e,"},\n");
        }
        ga_put(e,"};\n");
    }
    for (size_t i=0; i<gnode_array_size(e->functions); ++i)
        if (!ga_function_owner(e,(gnode_function_decl_t *)gnode_array_get(e->functions,i))) ++exports;
    if (exports) {
        ga_put(e,"static const gravity_aot_export ga_%s_exports[] = {\n",e->prefix);
        for (size_t i=0; i<gnode_array_size(e->functions); ++i) {
            gnode_function_decl_t *f=(gnode_function_decl_t *)gnode_array_get(e->functions,i); if (ga_function_owner(e,f)) continue;
            ga_put(e,"{"); text(e,f->identifier); ga_put(e,",%zu,",gnode_array_size(f->params)-1); ga_function_name(e,f);
            ga_put(e,",&ga_%s_declarations[%d]},\n",e->prefix,ga_declaration_index(e,(gnode_t *)f));
        }
        ga_put(e,"};\n");
    }
    ga_put(e,"const gravity_aot_module *%s_get_module(void) {\nstatic const gravity_aot_module m={GRAVITY_AOT_ABI_VERSION,%zu,",e->prefix,exports);
    if (exports) ga_put(e,"ga_%s_exports",e->prefix); else ga_put(e,"NULL");
    ga_put(e,",%zu,%zu,",classes,declarations);
    if (classes) ga_put(e,"ga_%s_types",e->prefix); else ga_put(e,"NULL");
    ga_put(e,",ga_%s_declarations};\nreturn &m;\n}\n",e->prefix);
}
