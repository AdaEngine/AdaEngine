#ifndef GRAVITY_AOT_TASKS_H
#define GRAVITY_AOT_TASKS_H
#include "gravity_aot_runtime.h"
/* Native tasks are arena-owned coroutines, never VM fibers. Every poll consumes
 * the caller's fuel/depth budget. Borrowed host handles keep their generation;
 * using a callback capability after suspension fails before dereferencing it. */
enum { GA_TASK_CREATED, GA_TASK_RUNNING, GA_TASK_PENDING, GA_TASK_COMPLETE, GA_TASK_CANCELLED, GA_TASK_FAILED };
struct gravity_aot_task {
    void (*resume)(gravity_aot_context *, gravity_aot_task *);
    gravity_aot_value *values;
    uint64_t *cursors;
    gravity_aot_value waiting, result;
    uint32_t pc, state, error, value_count;
};
static inline gravity_aot_value gravity_aot_task_new(gravity_aot_context *c,
    void (*resume)(gravity_aot_context *, gravity_aot_task *), uint32_t values, uint32_t cursors) {
    gravity_aot_value v=gravity_aot_null();
    if (c->abi_version!=GRAVITY_AOT_ABI_VERSION) { gravity_aot_error(c,GRAVITY_AOT_BAD_ABI); return v; }
    if (!gravity_aot_tick(c)) return v;
    if ((size_t)values>(SIZE_MAX-sizeof(gravity_aot_task))/sizeof(gravity_aot_value)) { gravity_aot_error(c,GRAVITY_AOT_MEMORY); return v; }
    size_t size=sizeof(gravity_aot_task)+(size_t)values*sizeof(gravity_aot_value);
    if ((size_t)cursors>(SIZE_MAX-size)/sizeof(uint64_t)) { gravity_aot_error(c,GRAVITY_AOT_MEMORY); return v; }
    size+=(size_t)cursors*sizeof(uint64_t);
    gravity_aot_task *task=(gravity_aot_task *)gravity_aot_allocate(c,size);
    if (!task) return v;
    unsigned char *bytes=(unsigned char *)task;
    for (size_t i=0;i<size;++i) bytes[i]=0;
    task->value_count=values; task->resume=resume; task->values=(gravity_aot_value *)(task+1); task->cursors=(uint64_t *)(task->values+values);
    v.kind=GRAVITY_AOT_TASK; v.task=task; return v;
}
/* Explicit @nonsendable values may not enter a suspended frame, including
 * values nested in ordinary objects/lists. Ancestor identity breaks cycles. */
static inline int gravity_aot_suspend_value(gravity_aot_context *c,gravity_aot_value value,void **path,uint32_t depth) {
    if (!gravity_aot_tick(c)) return 0;
    if (value.kind!=GRAVITY_AOT_OBJECT && value.kind!=GRAVITY_AOT_LIST) return 1;
    if (depth>=64) { gravity_aot_error(c,GRAVITY_AOT_LIMIT); return 0; }
    for (uint32_t i=0;i<depth;++i) if (path[i]==value.handle) return 1;
    path[depth]=value.handle;
    if (value.kind==GRAVITY_AOT_OBJECT && value.object) {
        const gravity_aot_class *type=value.object->type;
        const gravity_aot_declaration *declaration=type->declaration;
        for (uint32_t i=0;i<declaration->attribute_count;++i) if (!gravity_aot_text_compare(declaration->attributes[i].name,"nonsendable")) {
            gravity_aot_error(c,GRAVITY_AOT_TYPE); return 0;
        }
        for (uint32_t i=0;i<type->field_count;++i) if (!gravity_aot_suspend_value(c,value.object->fields[i],path,depth+1)) return 0;
    } else if (value.kind==GRAVITY_AOT_LIST && value.list) {
        for (uint32_t i=0;i<value.list->count;++i) if (!gravity_aot_suspend_value(c,value.list->items[i],path,depth+1)) return 0;
    }
    return 1;
}
static inline int gravity_aot_task_suspend(gravity_aot_context *c,gravity_aot_task *task) {
    void *path[64];
    for (uint32_t i=0;i<task->value_count;++i) if (!gravity_aot_suspend_value(c,task->values[i],path,0)) return 0;
    return 1;
}
static inline void gravity_aot_task_cancel(gravity_aot_context *,gravity_aot_value);
static inline void gravity_aot_task_release_frame(gravity_aot_task *task) {
    for (uint32_t i=0;i<task->value_count;++i) task->values[i]=gravity_aot_null();
    task->waiting=gravity_aot_null();
}
static inline void gravity_aot_task_fail(gravity_aot_context *c,gravity_aot_task *task) {
    uint32_t error=c->error;
    task->state=GA_TASK_FAILED; task->error=error;
    c->error=0;
    if (task->waiting.kind!=GRAVITY_AOT_NULL) gravity_aot_task_cancel(c,task->waiting);
    c->error=error;
    gravity_aot_task_release_frame(task);
}
static inline int gravity_aot_task_poll(gravity_aot_context *c, gravity_aot_value value, gravity_aot_value *result) {
    if (!gravity_aot_valid(c,value) || !gravity_aot_tick(c)) return 0;
    if (value.kind==GRAVITY_AOT_DURABLE_HOST) {
        gravity_aot_value done=gravity_aot_call(c,value,"isDone",NULL,0);
        if (c->error || !gravity_aot_truth(c,done)) return 0;
        *result=gravity_aot_call(c,value,"result",NULL,0); return !c->error;
    }
    if (value.kind!=GRAVITY_AOT_TASK || !value.task) { gravity_aot_error(c,GRAVITY_AOT_TYPE); return 0; }
    gravity_aot_task *task=value.task;
    if (task->state==GA_TASK_FAILED) { gravity_aot_error(c,task->error); return 0; }
    if (task->state==GA_TASK_CANCELLED) { gravity_aot_error(c,GRAVITY_AOT_CANCELLED); return 0; }
    if (task->state==GA_TASK_COMPLETE) { *result=task->result; gravity_aot_task_release_frame(task); return 1; }
    if (task->state==GA_TASK_RUNNING || c->depth>=c->max_depth) { gravity_aot_error(c,GRAVITY_AOT_LIMIT); return 0; }
    if (!task->resume) return 0; /* externally completed promise */
    ++c->depth; task->state=GA_TASK_RUNNING; task->resume(c,task); --c->depth;
    if (c->error) { gravity_aot_task_fail(c,task); return 0; }
    if (task->state==GA_TASK_COMPLETE) { *result=task->result; gravity_aot_task_release_frame(task); return 1; }
    if (!gravity_aot_task_suspend(c,task)) gravity_aot_task_fail(c,task);
    return 0;
}
static inline void gravity_aot_task_cancel(gravity_aot_context *c, gravity_aot_value value) {
    if (!gravity_aot_valid(c,value)) return;
    if (value.kind==GRAVITY_AOT_DURABLE_HOST) { (void)gravity_aot_call(c,value,"cancel",NULL,0); return; }
    if (value.kind!=GRAVITY_AOT_TASK || !value.task) { gravity_aot_error(c,GRAVITY_AOT_TYPE); return; }
    gravity_aot_task *task=value.task;
    if (task->state>=GA_TASK_COMPLETE) return;
    if (task->state==GA_TASK_RUNNING || c->depth>=c->max_depth) { gravity_aot_error(c,GRAVITY_AOT_LIMIT); return; }
    task->state=GA_TASK_CANCELLED;
    ++c->depth;
    if (task->waiting.kind!=GRAVITY_AOT_NULL) gravity_aot_task_cancel(c,task->waiting);
    --c->depth;
    gravity_aot_task_release_frame(task);
}
static inline gravity_aot_value gravity_aot_task_call(gravity_aot_context *c, gravity_aot_value value,
    const char *name,const gravity_aot_value *args,uint32_t count) {
    gravity_aot_task *task=value.task;
    if (!task) { gravity_aot_error(c,GRAVITY_AOT_TYPE); return gravity_aot_null(); }
    if (!gravity_aot_text_compare(name,"complete") && count==1 && !task->resume) {
        if (task->state<GA_TASK_COMPLETE) { task->result=gravity_aot_copy(c,args[0]); task->state=GA_TASK_COMPLETE; }
        return gravity_aot_null();
    }
    if (count) { gravity_aot_error(c,GRAVITY_AOT_ARITY); return gravity_aot_null(); }
    if (!gravity_aot_text_compare(name,"cancel")) { gravity_aot_task_cancel(c,value); return gravity_aot_null(); }
    if (!gravity_aot_text_compare(name,"isComplete")) return gravity_aot_bool(task->state>=GA_TASK_COMPLETE);
    if (!gravity_aot_text_compare(name,"status")) {
        const char *status=task->state==GA_TASK_COMPLETE?"completed":task->state==GA_TASK_CANCELLED?"cancelled":task->state==GA_TASK_FAILED?"failed":"running";
        uint32_t length=0; while(status[length]) ++length; return gravity_aot_string(status,length);
    }
    if (!gravity_aot_text_compare(name,"result") && task->state==GA_TASK_COMPLETE) return task->result;
    gravity_aot_error(c,GRAVITY_AOT_METHOD); return gravity_aot_null();
}
#endif
