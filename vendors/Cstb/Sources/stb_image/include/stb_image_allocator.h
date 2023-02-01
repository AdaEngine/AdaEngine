#ifndef stb_image_allocator_h
#define stb_image_allocator_h

#include <stdlib.h>
#include <stdint.h>

typedef struct stbi_allocator_overrides {
    void *_Nullable (*_Nullable stbi_alloc_override)(size_t length);
    void *_Nullable (*_Nullable stbi_realloc_override)(void* _Nullable address, size_t oldLength, size_t newLength);
    void (*_Nullable stbi_free_override)(void* _Nullable address);
    void *_Nullable allocator_context;
} stbi_allocator_overrides;

extern void *_Nullable stbi_get_allocator_context(void);

// Thread-local if STBI_NO_THREAD_LOCALS isn't defined. Returns the old overrides
extern stbi_allocator_overrides stbi_set_allocator_overrides(stbi_allocator_overrides overrides);

#endif /* stb_image_allocator_h */
