#ifndef ADA_NAVIGATION_H
#define ADA_NAVIGATION_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AENavigationMesh AENavigationMesh;

typedef struct {
    float radius;
    float height;
    float maximumSlope;
    float maximumClimb;
    float cellSize;
    float cellHeight;
    int32_t maximumGridCells;
} AENavigationBuildSettings;

typedef struct {
    float extents[3];
    int32_t maximumNodes;
    int32_t maximumPolygons;
    int32_t maximumWaypoints;
    uint16_t includeFlags;
    uint16_t excludeFlags;
} AENavigationQuerySettings;

enum AENavigationResult {
    AE_NAV_SUCCESS = 0,
    AE_NAV_INVALID_INPUT = 1,
    AE_NAV_OUT_OF_MEMORY = 2,
    AE_NAV_BUILD_FAILED = 3,
    AE_NAV_EMPTY_MESH = 4,
    AE_NAV_START_OUTSIDE = 5,
    AE_NAV_TARGET_OUTSIDE = 6,
    AE_NAV_QUERY_FAILED = 7,
    AE_NAV_PARTIAL = 8,
    AE_NAV_SEARCH_LIMIT = 9,
    AE_NAV_BUFFER_LIMIT = 10
};

/* Checks all single-tile sections and references before Detour sees persisted bytes. */
int32_t ae_navigation_validate(const uint8_t *bytes, int32_t count,
    AENavigationBuildSettings *agent, int32_t *polygonCount);
AENavigationMesh *ae_navigation_create(const uint8_t *bytes, int32_t count);
void ae_navigation_destroy(AENavigationMesh *mesh);
void ae_navigation_free_bytes(uint8_t *bytes);

/* Polygon fans for debug overlays. Returns the required vertex count, or -1 on failure. */
int32_t ae_navigation_debug_triangles(AENavigationMesh *mesh, float *vertices, int32_t capacity);

/* Calls on the same mesh must be serialized by its Swift actor owner. */
int32_t ae_navigation_find_path(
    AENavigationMesh *mesh, const float *start, const float *target,
    const AENavigationQuerySettings *settings, float *waypoints,
    uint64_t *corridor, int32_t *waypointCount, int32_t *polygonCount);

#ifdef __cplusplus
}
#endif
#endif
