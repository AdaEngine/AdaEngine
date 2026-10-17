#include "CNavigation.h"
#include "DetourAlloc.h"
#include "DetourNavMesh.h"
#include "DetourNavMeshQuery.h"
#include <cmath>
#include <cstring>
#include <new>

struct AENavigationMesh {
    dtNavMesh *mesh = nullptr;
    dtNavMeshQuery *query = nullptr;
    int maximumNodes = 0;
    ~AENavigationMesh() { dtFreeNavMeshQuery(query); dtFreeNavMesh(mesh); }
};

AENavigationMesh *ae_navigation_create(const uint8_t *bytes, int32_t count) {
    if (!ae_navigation_validate(bytes, count, nullptr, nullptr)) return nullptr;
    auto result = new (std::nothrow) AENavigationMesh();
    if (!result) return nullptr;
    result->mesh = dtAllocNavMesh();
    result->query = dtAllocNavMeshQuery();
    auto copy = static_cast<unsigned char *>(dtAlloc(count, DT_ALLOC_PERM));
    if (!result->mesh || !result->query || !copy) {
        dtFree(copy);
        delete result;
        return nullptr;
    }
    std::memcpy(copy, bytes, count);
    if (dtStatusFailed(result->mesh->init(copy, count, DT_TILE_FREE_DATA))) {
        dtFree(copy);
        delete result;
        return nullptr;
    }
    return result;
}

void ae_navigation_destroy(AENavigationMesh *mesh) { delete mesh; }
void ae_navigation_free_bytes(uint8_t *bytes) { dtFree(bytes); }

int32_t ae_navigation_debug_triangles(AENavigationMesh *mesh, float *vertices, int32_t capacity) {
    if (!mesh) return -1;
    const auto tile = static_cast<const dtNavMesh *>(mesh->mesh)->getTile(0);
    if (!tile || !tile->header) return -1;
    int count = 0;
    for (int p = 0; p < tile->header->polyCount; ++p) count += (tile->polys[p].vertCount - 2) * 3;
    if (!vertices || capacity < count) return count;
    int cursor = 0;
    for (int p = 0; p < tile->header->polyCount; ++p) {
        const auto &polygon = tile->polys[p];
        for (int i = 1; i < polygon.vertCount - 1; ++i) {
            const int corners[3] = {0, i, i + 1};
            for (int corner : corners) {
                std::memcpy(vertices + cursor * 3, tile->verts + polygon.verts[corner] * 3, sizeof(float) * 3);
                ++cursor;
            }
        }
    }
    return count;
}

int32_t ae_navigation_find_path(
    AENavigationMesh *mesh, const float *start, const float *target,
    const AENavigationQuerySettings *settings, float *waypoints,
    uint64_t *corridor, int32_t *waypointCount, int32_t *polygonCount) {
    if (!mesh || !start || !target || !settings || !waypoints || !corridor || !waypointCount || !polygonCount)
        return AE_NAV_INVALID_INPUT;
    *waypointCount = 0;
    *polygonCount = 0;
    // Detour 1.6 derives its hash table size from maxNodes / 4; fewer than 4 is unsafe.
    if (settings->maximumNodes < 4 || settings->maximumNodes > 65535 ||
        settings->maximumPolygons < 1 || settings->maximumPolygons > 65535 ||
        settings->maximumWaypoints < 2 || settings->maximumWaypoints > 65535) return AE_NAV_INVALID_INPUT;
    for (int i = 0; i < 3; ++i) {
        if (!std::isfinite(start[i]) || !std::isfinite(target[i]) ||
            !std::isfinite(settings->extents[i]) || settings->extents[i] <= 0) return AE_NAV_INVALID_INPUT;
        if (!std::isfinite(start[i] + settings->extents[i]) || !std::isfinite(start[i] - settings->extents[i]) ||
            !std::isfinite(target[i] + settings->extents[i]) || !std::isfinite(target[i] - settings->extents[i])) return AE_NAV_INVALID_INPUT;
    }
    // init() reuses a larger pool, so recreate when shrinking to honor each request's budget.
    if (mesh->maximumNodes != settings->maximumNodes) {
        dtFreeNavMeshQuery(mesh->query);
        mesh->query = dtAllocNavMeshQuery();
        mesh->maximumNodes = 0;
        if (!mesh->query || dtStatusFailed(mesh->query->init(mesh->mesh, settings->maximumNodes))) return AE_NAV_OUT_OF_MEMORY;
        mesh->maximumNodes = settings->maximumNodes;
    }
    auto query = mesh->query;
    dtQueryFilter filter;
    filter.setIncludeFlags(settings->includeFlags);
    filter.setExcludeFlags(settings->excludeFlags);
    dtPolyRef startRef = 0, targetRef = 0;
    float projectedStart[3], projectedTarget[3];
    if (dtStatusFailed(query->findNearestPoly(start, settings->extents, &filter, &startRef, projectedStart)))
        return AE_NAV_QUERY_FAILED;
    if (!startRef) return AE_NAV_START_OUTSIDE;
    if (dtStatusFailed(query->findNearestPoly(target, settings->extents, &filter, &targetRef, projectedTarget)))
        return AE_NAV_QUERY_FAILED;
    if (!targetRef) return AE_NAV_TARGET_OUTSIDE;

    auto polygons = static_cast<dtPolyRef *>(dtAlloc(sizeof(dtPolyRef) * settings->maximumPolygons, DT_ALLOC_TEMP));
    if (!polygons) return AE_NAV_OUT_OF_MEMORY;
    int count = 0;
    auto status = query->findPath(startRef, targetRef, projectedStart, projectedTarget, &filter,
                                 polygons, &count, settings->maximumPolygons);
    if (dtStatusFailed(status) || count == 0) {
        dtFree(polygons);
        return AE_NAV_QUERY_FAILED;
    }
    int32_t result = AE_NAV_SUCCESS;
    if (dtStatusDetail(status, DT_BUFFER_TOO_SMALL)) result = AE_NAV_BUFFER_LIMIT;
    else if (dtStatusDetail(status, DT_OUT_OF_NODES)) result = AE_NAV_SEARCH_LIMIT;
    else if (polygons[count - 1] != targetRef || dtStatusDetail(status, DT_PARTIAL_RESULT)) result = AE_NAV_PARTIAL;
    if (polygons[count - 1] != targetRef &&
        dtStatusFailed(query->closestPointOnPoly(polygons[count - 1], projectedTarget, projectedTarget, nullptr))) {
        dtFree(polygons);
        return AE_NAV_QUERY_FAILED;
    }
    int pointCount = 0;
    status = query->findStraightPath(projectedStart, projectedTarget, polygons, count,
                                    waypoints, nullptr, nullptr, &pointCount, settings->maximumWaypoints);
    if (dtStatusFailed(status)) result = AE_NAV_QUERY_FAILED;
    else if (dtStatusDetail(status, DT_BUFFER_TOO_SMALL)) result = AE_NAV_BUFFER_LIMIT;
    for (int i = 0; i < count; ++i) corridor[i] = static_cast<uint64_t>(polygons[i]);
    *polygonCount = count;
    *waypointCount = pointCount;
    dtFree(polygons);
    return result;
}
