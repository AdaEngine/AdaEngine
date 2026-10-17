#ifndef GRAVITY_AOT_OBJECTS_H
#define GRAVITY_AOT_OBJECTS_H
#include "gravity_aot_runtime.h"
/* The caller supplies memory. No implicit GC, global allocator, or shared VM. */
typedef struct { unsigned char *buffer; size_t capacity, used; } gravity_aot_arena;
static inline void *gravity_aot_arena_allocate(void *data, size_t size) {
    gravity_aot_arena *a = (gravity_aot_arena *)data;
    if (!a || !a->buffer || a->used > a->capacity) return NULL;
    size_t alignment = sizeof(double) > sizeof(void *) ? sizeof(double) : sizeof(void *);
    size_t remainder = ((uintptr_t)a->buffer + a->used) % alignment;
    size_t padding = remainder ? alignment - remainder : 0;
    if (padding > a->capacity-a->used || size > a->capacity-a->used-padding) return NULL;
    void *p = a->buffer+a->used+padding; a->used += padding+size; return p;
}
static inline void *gravity_aot_allocate(gravity_aot_context *c, size_t size) {
    if (c->error) return NULL;
    void *p = c->allocate ? c->allocate(c->allocation_data, size) : NULL;
    if (!p) gravity_aot_error(c, GRAVITY_AOT_MEMORY);
    return p;
}
static inline int gravity_aot_matches(gravity_aot_context *c, gravity_aot_value v, const char *type) {
    if (!gravity_aot_valid(c,v)) return 0;
    int match=!gravity_aot_text_compare(type,"Int")?v.kind==GRAVITY_AOT_INT:!gravity_aot_text_compare(type,"Bool")?v.kind==GRAVITY_AOT_BOOL:
        !gravity_aot_text_compare(type,"Float")?v.kind==GRAVITY_AOT_FLOAT:!gravity_aot_text_compare(type,"String")?v.kind==GRAVITY_AOT_STRING:
        !gravity_aot_text_compare(type,"List")?v.kind==GRAVITY_AOT_LIST:
        v.kind==GRAVITY_AOT_HOST || (v.kind==GRAVITY_AOT_OBJECT && v.object && !gravity_aot_text_compare(type,v.object->type->declaration->name));
    if (!match) gravity_aot_error(c,GRAVITY_AOT_TYPE); return match;
}
static inline gravity_aot_value gravity_aot_copy(gravity_aot_context *c, gravity_aot_value v);
static inline gravity_aot_value gravity_aot_new(gravity_aot_context *c, const gravity_aot_class *type) {
    gravity_aot_value v = gravity_aot_null();
    if (!type || !gravity_aot_tick(c)) return v;
    if ((size_t)type->field_count > (SIZE_MAX-sizeof(gravity_aot_object))/sizeof(gravity_aot_value)) {
        gravity_aot_error(c, GRAVITY_AOT_MEMORY); return v;
    }
    gravity_aot_object *o = (gravity_aot_object *)gravity_aot_allocate(c, sizeof(*o)+type->field_count*sizeof(gravity_aot_value));
    if (!o) return v;
    o->type = type; o->fields = (gravity_aot_value *)(o+1);
    for (uint32_t i=0; i<type->field_count; ++i) o->fields[i] = gravity_aot_copy(c, type->fields[i].default_value);
    v.object = o; v.kind = GRAVITY_AOT_OBJECT;
    for (uint32_t i=0;i<type->field_count;++i) if (type->fields[i].initialize) {
        if (c->depth>=c->max_depth) { gravity_aot_error(c,GRAVITY_AOT_LIMIT); return gravity_aot_null(); }
        ++c->depth;
        o->fields[i]=type->fields[i].initialize(c,v);
        --c->depth;
        if (c->error) return gravity_aot_null();
    }
    return v;
}
static inline gravity_aot_value gravity_aot_copy(gravity_aot_context *c, gravity_aot_value v) {
    if (!gravity_aot_valid(c, v)) return gravity_aot_null();
    if (v.kind == GRAVITY_AOT_OBJECT && v.object && v.object->type->is_struct) {
        const gravity_aot_class *type=v.object->type;
        gravity_aot_value copy=gravity_aot_null();
        if (!gravity_aot_tick(c)) return copy;
        if ((size_t)type->field_count>(SIZE_MAX-sizeof(gravity_aot_object))/sizeof(gravity_aot_value)) {
            gravity_aot_error(c,GRAVITY_AOT_MEMORY); return copy;
        }
        gravity_aot_object *object=(gravity_aot_object *)gravity_aot_allocate(c,sizeof(*object)+type->field_count*sizeof(gravity_aot_value));
        if (!object) return copy;
        object->type=type; object->fields=(gravity_aot_value *)(object+1);
        copy.kind=GRAVITY_AOT_OBJECT; copy.object=object;
        for (uint32_t i=0; i<v.object->type->field_count; ++i) copy.object->fields[i] = gravity_aot_copy(c, v.object->fields[i]);
        return copy;
    }
    return v;
}
/* Compiled self-field accesses use a resolved slot, avoiding name lookup. */
static inline gravity_aot_value gravity_aot_field_get(gravity_aot_context *c, gravity_aot_value receiver, uint32_t slot) {
    if (!gravity_aot_valid(c,receiver)) return gravity_aot_null();
    if (receiver.kind!=GRAVITY_AOT_OBJECT || !receiver.object || slot>=receiver.object->type->field_count) {
        gravity_aot_error(c,GRAVITY_AOT_FIELD); return gravity_aot_null();
    }
    return receiver.object->fields[slot];
}
static inline int gravity_aot_field_set(gravity_aot_context *c, gravity_aot_value receiver, uint32_t slot, gravity_aot_value value) {
    if (!gravity_aot_valid(c,receiver) || !gravity_aot_valid(c,value)) return 0;
    if (receiver.kind!=GRAVITY_AOT_OBJECT || !receiver.object || slot>=receiver.object->type->field_count || receiver.object->type->fields[slot].readonly) {
        gravity_aot_error(c,GRAVITY_AOT_FIELD); return 0;
    }
    receiver.object->fields[slot]=gravity_aot_copy(c,value); return !c->error;
}
static inline gravity_aot_value gravity_aot_get(gravity_aot_context *c, gravity_aot_value receiver, const char *name) {
    gravity_aot_value result = gravity_aot_null();
    if (!gravity_aot_valid(c, receiver)) return result;
    if (receiver.kind == GRAVITY_AOT_OBJECT && receiver.object) {
        const gravity_aot_class *t = receiver.object->type;
        for (uint32_t i=0; i<t->field_count; ++i)
            if (!gravity_aot_text_compare(name,t->fields[i].declaration->name)) return receiver.object->fields[i];
        gravity_aot_error(c, GRAVITY_AOT_FIELD);
    } else if (receiver.kind == GRAVITY_AOT_LIST && !gravity_aot_text_compare(name,"count")) return gravity_aot_int(receiver.list->count);
    else if (receiver.kind == GRAVITY_AOT_STRING && !gravity_aot_text_compare(name,"count")) {
        gravity_aot_error(c, GRAVITY_AOT_TYPE); /* byte length is not Unicode character count */
    } else if ((receiver.kind == GRAVITY_AOT_HOST || receiver.kind == GRAVITY_AOT_DURABLE_HOST || receiver.kind == GRAVITY_AOT_NULL) && c->host && c->host->get) {
        if (!c->host->get(c->host_data,receiver,name,&result)) gravity_aot_error(c, GRAVITY_AOT_HOST_ERROR);
        gravity_aot_valid(c,result);
    } else gravity_aot_error(c, GRAVITY_AOT_FIELD);
    return result;
}
static inline int gravity_aot_set(gravity_aot_context *c, gravity_aot_value receiver, const char *name, gravity_aot_value value) {
    if (!gravity_aot_valid(c,receiver) || !gravity_aot_valid(c,value)) return 0;
    if (receiver.kind == GRAVITY_AOT_OBJECT && receiver.object) {
        const gravity_aot_class *t = receiver.object->type;
        for (uint32_t i=0; i<t->field_count; ++i) if (!gravity_aot_text_compare(name,t->fields[i].declaration->name)) {
            if (t->fields[i].readonly) { gravity_aot_error(c, GRAVITY_AOT_FIELD); return 0; }
            receiver.object->fields[i] = gravity_aot_copy(c,value); return !c->error;
        }
        gravity_aot_error(c, GRAVITY_AOT_FIELD);
    } else if ((receiver.kind == GRAVITY_AOT_HOST || receiver.kind == GRAVITY_AOT_DURABLE_HOST) && c->host && c->host->set) {
        if (!c->host->set(c->host_data,receiver,name,value)) gravity_aot_error(c, GRAVITY_AOT_HOST_ERROR);
    } else gravity_aot_error(c, GRAVITY_AOT_FIELD);
    return !c->error;
}
static inline gravity_aot_value gravity_aot_call(gravity_aot_context *c, gravity_aot_value receiver,
                                                const char *name, const gravity_aot_value *args, uint32_t count) {
    gravity_aot_value result = gravity_aot_null();
    if (!gravity_aot_valid(c,receiver)) return result;
    if (count && !args) { gravity_aot_error(c,GRAVITY_AOT_ARITY); return result; }
    for (uint32_t i=0; i<count; ++i) if (!gravity_aot_valid(c,args[i])) return result;
    if (receiver.kind == GRAVITY_AOT_TASK) return gravity_aot_task_call(c,receiver,name,args,count);
    if (receiver.kind == GRAVITY_AOT_OBJECT && receiver.object) {
        const gravity_aot_class *t = receiver.object->type;
        for (uint32_t i=0; i<t->method_count; ++i) if (!gravity_aot_text_compare(name,t->methods[i].name))
            return t->methods[i].call(c,receiver,args,count);
        gravity_aot_error(c, GRAVITY_AOT_METHOD);
    } else if ((receiver.kind == GRAVITY_AOT_HOST || receiver.kind == GRAVITY_AOT_DURABLE_HOST || receiver.kind == GRAVITY_AOT_NULL) && c->host && c->host->call) {
        if (!c->host->call(c->host_data,receiver,name,args,count,&result)) gravity_aot_error(c, GRAVITY_AOT_HOST_ERROR);
        gravity_aot_valid(c,result);
    } else gravity_aot_error(c, GRAVITY_AOT_HOST_ERROR);
    return result;
}
static inline gravity_aot_value gravity_aot_construct(gravity_aot_context *c, const gravity_aot_class *t,
                                                     const gravity_aot_value *args, uint32_t count) {
    gravity_aot_value v = gravity_aot_new(c,t);
    if (c->error) return gravity_aot_null();
    for (uint32_t i=0; i<t->method_count; ++i) if (!gravity_aot_text_compare(t->methods[i].name,"init")) {
        (void)t->methods[i].call(c,v,args,count); return c->error ? gravity_aot_null() : v;
    }
    if (count) { gravity_aot_error(c, GRAVITY_AOT_ARITY); return gravity_aot_null(); }
    return v;
}
static inline gravity_aot_value gravity_aot_list_new(gravity_aot_context *c, const gravity_aot_value *items, uint32_t count) {
    gravity_aot_value v = gravity_aot_null();
    if ((size_t)count > (SIZE_MAX-sizeof(gravity_aot_list))/sizeof(gravity_aot_value)) {
        gravity_aot_error(c, GRAVITY_AOT_MEMORY); return v;
    }
    gravity_aot_list *list = (gravity_aot_list *)gravity_aot_allocate(c,sizeof(*list)+count*sizeof(gravity_aot_value));
    if (!list) return v;
    list->count=count; list->items=(gravity_aot_value *)(list+1);
    for (uint32_t i=0; i<count; ++i) list->items[i]=gravity_aot_copy(c,items[i]);
    v.kind=GRAVITY_AOT_LIST; v.list=list; return v;
}
static inline gravity_aot_value gravity_aot_range_new(gravity_aot_context *c, gravity_aot_value start, gravity_aot_value end, uint32_t inclusive) {
    gravity_aot_value v = gravity_aot_null();
    if (start.kind != GRAVITY_AOT_INT || end.kind != GRAVITY_AOT_INT) { gravity_aot_error(c,GRAVITY_AOT_TYPE); return v; }
    gravity_aot_range *r=(gravity_aot_range *)gravity_aot_allocate(c,sizeof(*r));
    if (!r) return v;
    r->start=start.integer; r->end=end.integer; r->inclusive=inclusive;
    v.kind=GRAVITY_AOT_RANGE; v.range=r; return v;
}
static inline int gravity_aot_next(gravity_aot_context *c, gravity_aot_value iterable, uint64_t *state, gravity_aot_value *value) {
    if (!gravity_aot_valid(c,iterable)) return -1;
    if (iterable.kind == GRAVITY_AOT_LIST) {
        if (*state >= iterable.list->count) return 0;
        *value=iterable.list->items[(*state)++]; return 1;
    }
    if (iterable.kind == GRAVITY_AOT_RANGE) {
        gravity_aot_range *r=iterable.range;
        uint64_t span = r->end >= r->start ? (uint64_t)r->end-(uint64_t)r->start : (uint64_t)r->start-(uint64_t)r->end;
        if (span==UINT64_MAX) { gravity_aot_error(c,GRAVITY_AOT_LIMIT); return -1; }
        if (*state > span || (*state == span && !r->inclusive)) return 0;
        *value=gravity_aot_int((int64_t)(r->end >= r->start ? (uint64_t)r->start+*state : (uint64_t)r->start-*state));
        ++*state; return 1;
    }
    if (iterable.kind == GRAVITY_AOT_HOST && c->host && c->host->next) {
        int next=c->host->next(c->host_data,iterable,state,value);
        if (next < 0 || (next > 0 && !gravity_aot_valid(c,*value))) gravity_aot_error(c,GRAVITY_AOT_HOST_ERROR);
        return c->error ? -1 : next;
    }
    gravity_aot_error(c,GRAVITY_AOT_TYPE); return -1;
}
static inline gravity_aot_value gravity_aot_index_get(gravity_aot_context *c, gravity_aot_value v, gravity_aot_value index) {
    if (!gravity_aot_valid(c,v)) return gravity_aot_null();
    if (v.kind==GRAVITY_AOT_LIST && index.kind==GRAVITY_AOT_INT && index.integer>=0 &&
        (uint64_t)index.integer<v.list->count) return v.list->items[index.integer];
    gravity_aot_error(c,GRAVITY_AOT_FIELD); return gravity_aot_null();
}
static inline int gravity_aot_index_set(gravity_aot_context *c, gravity_aot_value v, gravity_aot_value index, gravity_aot_value value) {
    if (!gravity_aot_valid(c,v)) return 0;
    if (v.kind==GRAVITY_AOT_LIST && index.kind==GRAVITY_AOT_INT && index.integer>=0 &&
        (uint64_t)index.integer<v.list->count) {
        v.list->items[index.integer]=gravity_aot_copy(c,value); return !c->error;
    }
    gravity_aot_error(c,GRAVITY_AOT_FIELD); return 0;
}
#endif
