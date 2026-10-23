#ifndef ADA_NAVIGATION_BAKING_H
#define ADA_NAVIGATION_BAKING_H

#include "CNavigation.h"

#ifdef __cplusplus
extern "C" {
#endif

/* All arrays are copied; returned bytes are freed with ae_navigation_free_bytes. */
int32_t ae_navigation_bake(
    const float *vertices, int32_t vertexCount, const int32_t *indices, int32_t triangleCount,
    const AENavigationBuildSettings *settings, uint8_t **bytes, int32_t *byteCount, int32_t *polygonCount);

#ifdef __cplusplus
}
#endif
#endif
