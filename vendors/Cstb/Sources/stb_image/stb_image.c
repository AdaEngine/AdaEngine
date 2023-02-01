#include "stb_image_allocator.h"

#ifndef STBI_NO_THREAD_LOCALS
   #if defined(__cplusplus) &&  __cplusplus >= 201103L
      #define STBI_ALLOCATOR_THREAD_LOCAL       thread_local
   #elif defined(__GNUC__) && __GNUC__ < 5
      #define STBI_ALLOCATOR_THREAD_LOCAL       __thread
   #elif defined(_MSC_VER)
      #define STBI_ALLOCATOR_THREAD_LOCAL       __declspec(thread)
   #elif defined (__STDC_VERSION__) && __STDC_VERSION__ >= 201112L && !defined(__STDC_NO_THREADS__)
      #define STBI_ALLOCATOR_THREAD_LOCAL       _Thread_local
   #endif

   #ifndef STBI_ALLOCATOR_THREAD_LOCAL
      #if defined(__GNUC__)
        #define STBI_ALLOCATOR_THREAD_LOCAL       __thread
      #endif
   #endif
#endif

#ifdef STBI_ALLOCATOR_THREAD_LOCAL
STBI_ALLOCATOR_THREAD_LOCAL
#endif
static void *_Nullable stbi_allocator_context = NULL;

#ifdef STBI_ALLOCATOR_THREAD_LOCAL
STBI_ALLOCATOR_THREAD_LOCAL
#endif
static void *_Nullable (*stbi_alloc_override)(size_t length) = NULL;
#ifdef STBI_ALLOCATOR_THREAD_LOCAL
STBI_ALLOCATOR_THREAD_LOCAL
#endif
static void *_Nullable (*stbi_realloc_override)(void* address, size_t oldLength, size_t newLength) = NULL;
#ifdef STBI_ALLOCATOR_THREAD_LOCAL
STBI_ALLOCATOR_THREAD_LOCAL
#endif
static void (*stbi_free_override)(void* address) = NULL;

static void* stbi_malloc(size_t size) {
    if (stbi_alloc_override) {
        return stbi_alloc_override(size);
    }
    return malloc(size);
}

static void* stbi_realloc_size(void* address, size_t oldLength, size_t newLength) {
    if (stbi_realloc_override) {
        return stbi_realloc_override(address, oldLength, newLength);
    }
    return realloc(address, newLength);
}

static void stbi_free(void* address) {
    if (stbi_free_override) {
        stbi_free_override(address);
        return;
    }
    free(address);
}

#define STBI_MALLOC(sz)           stbi_malloc(sz)
#define STBI_REALLOC_SIZED(p,oldsz,newsz) stbi_realloc_size(p,oldsz,newsz)
#define STBI_FREE(p)              stbi_free(p)


void *_Nullable stbi_get_allocator_context(void) {
    return stbi_allocator_context;
}

stbi_allocator_overrides stbi_set_allocator_overrides(stbi_allocator_overrides overrides) {
    stbi_allocator_overrides result = { stbi_alloc_override, stbi_realloc_override, stbi_free_override, stbi_allocator_context };
    
    stbi_alloc_override = overrides.stbi_alloc_override;
    stbi_realloc_override = overrides.stbi_realloc_override;
    stbi_free_override = overrides.stbi_free_override;
    stbi_allocator_context = overrides.allocator_context;
    
    return result;
}

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image_include.h"
