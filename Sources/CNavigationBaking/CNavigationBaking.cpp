#include "CNavigationBaking.h"
#include "DetourNavMesh.h"
#include "DetourNavMeshBuilder.h"
#include "Recast.h"
#include <cmath>
#include <memory>
#include <new>

int32_t ae_navigation_bake(
    const float *vertices, int32_t vertexCount, const int32_t *indices, int32_t triangleCount,
    const AENavigationBuildSettings *settings, uint8_t **bytes, int32_t *byteCount, int32_t *polygonCount) {
    if (!vertices || !indices || !settings || !bytes || !byteCount || !polygonCount) return AE_NAV_INVALID_INPUT;
    *bytes = nullptr;
    *byteCount = 0;
    *polygonCount = 0;
    if (vertexCount < 3 || triangleCount < 1 || triangleCount > INT32_MAX / 3 || vertexCount > INT32_MAX / 3)
        return AE_NAV_INVALID_INPUT;
    if (!std::isfinite(settings->radius) || settings->radius <= 0 ||
        !std::isfinite(settings->height) || settings->height < 2 * settings->radius ||
        !std::isfinite(settings->maximumSlope) || settings->maximumSlope < 0 || settings->maximumSlope >= 90 ||
        !std::isfinite(settings->maximumClimb) || settings->maximumClimb < 0 || settings->maximumClimb >= settings->height ||
        !std::isfinite(settings->cellSize) || settings->cellSize <= 0 ||
        !std::isfinite(settings->cellHeight) || settings->cellHeight <= 0 || settings->maximumGridCells < 1)
        return AE_NAV_INVALID_INPUT;
    for (int i = 0; i < vertexCount * 3; ++i) if (!std::isfinite(vertices[i])) return AE_NAV_INVALID_INPUT;
    for (int i = 0; i < triangleCount * 3; ++i)
        if (indices[i] < 0 || indices[i] >= vertexCount) return AE_NAV_INVALID_INPUT;

    rcConfig config = {};
    config.cs = settings->cellSize;
    config.ch = settings->cellHeight;
    config.walkableSlopeAngle = settings->maximumSlope;
    const double heightCells = std::ceil(static_cast<double>(settings->height) / config.ch);
    const double climbCells = std::floor(static_cast<double>(settings->maximumClimb) / config.ch);
    const double radiusCells = std::ceil(static_cast<double>(settings->radius) / config.cs);
    if (heightCells > RC_SPAN_MAX_HEIGHT || climbCells > RC_SPAN_MAX_HEIGHT || radiusCells > 255) return AE_NAV_INVALID_INPUT;
    config.walkableHeight = static_cast<int>(heightCells);
    config.walkableClimb = static_cast<int>(climbCells);
    config.walkableRadius = static_cast<int>(radiusCells);
    config.maxEdgeLen = 0;
    config.maxSimplificationError = 1.3f;
    config.minRegionArea = 0;
    config.mergeRegionArea = 0;
    config.maxVertsPerPoly = DT_VERTS_PER_POLYGON;
    config.detailSampleDist = config.cs * 6;
    config.detailSampleMaxError = config.ch;
    rcCalcBounds(vertices, vertexCount, config.bmin, config.bmax);
    // Reserve headroom even for a completely flat input mesh.
    config.bmax[1] += settings->height + config.ch * 2;
    for (int i = 0; i < 3; ++i) {
        if (!std::isfinite(config.bmax[i]) || !std::isfinite(config.bmin[i])) return AE_NAV_INVALID_INPUT;
        const double cells = (static_cast<double>(config.bmax[i]) - config.bmin[i]) / (i == 1 ? config.ch : config.cs);
        if (cells > (i == 1 ? RC_SPAN_MAX_HEIGHT : 65000)) return AE_NAV_INVALID_INPUT;
    }
    rcCalcGridSize(config.bmin, config.bmax, config.cs, &config.width, &config.height);
    if (config.width < 1 || config.height < 1) return AE_NAV_EMPTY_MESH;
    if (static_cast<int64_t>(config.width) * config.height > settings->maximumGridCells) return AE_NAV_INVALID_INPUT;
    rcContext context;
    std::unique_ptr<rcHeightfield, decltype(&rcFreeHeightField)> field(rcAllocHeightfield(), rcFreeHeightField);
    std::unique_ptr<rcCompactHeightfield, decltype(&rcFreeCompactHeightfield)> compact(rcAllocCompactHeightfield(), rcFreeCompactHeightfield);
    std::unique_ptr<rcContourSet, decltype(&rcFreeContourSet)> contours(rcAllocContourSet(), rcFreeContourSet);
    std::unique_ptr<rcPolyMesh, decltype(&rcFreePolyMesh)> polygons(rcAllocPolyMesh(), rcFreePolyMesh);
    std::unique_ptr<rcPolyMeshDetail, decltype(&rcFreePolyMeshDetail)> detail(rcAllocPolyMeshDetail(), rcFreePolyMeshDetail);
    std::unique_ptr<unsigned char[]> areas(new (std::nothrow) unsigned char[triangleCount]());
    if (!field || !compact || !contours || !polygons || !detail || !areas) return AE_NAV_OUT_OF_MEMORY;
    if (!rcCreateHeightfield(&context, *field, config.width, config.height, config.bmin, config.bmax, config.cs, config.ch))
        return AE_NAV_BUILD_FAILED;
    rcMarkWalkableTriangles(&context, config.walkableSlopeAngle, vertices, vertexCount, indices, triangleCount, areas.get());
    if (!rcRasterizeTriangles(&context, vertices, vertexCount, indices, areas.get(), triangleCount, *field, config.walkableClimb))
        return AE_NAV_BUILD_FAILED;
    rcFilterLowHangingWalkableObstacles(&context, config.walkableClimb, *field);
    rcFilterLedgeSpans(&context, config.walkableHeight, config.walkableClimb, *field);
    rcFilterWalkableLowHeightSpans(&context, config.walkableHeight, *field);
    if (!rcBuildCompactHeightfield(&context, config.walkableHeight, config.walkableClimb, *field, *compact) ||
        !rcErodeWalkableArea(&context, config.walkableRadius, *compact) ||
        !rcBuildDistanceField(&context, *compact) ||
        !rcBuildRegions(&context, *compact, 0, config.minRegionArea, config.mergeRegionArea) ||
        !rcBuildContours(&context, *compact, config.maxSimplificationError, config.maxEdgeLen, *contours) ||
        !rcBuildPolyMesh(&context, *contours, config.maxVertsPerPoly, *polygons)) return AE_NAV_BUILD_FAILED;
    if (polygons->npolys == 0) return AE_NAV_EMPTY_MESH;
    if (polygons->nverts >= 65535 || polygons->npolys >= 32768) return AE_NAV_INVALID_INPUT;
    if (!rcBuildPolyMeshDetail(&context, *polygons, *compact, config.detailSampleDist, config.detailSampleMaxError, *detail))
        return AE_NAV_BUILD_FAILED;
    for (int i = 0; i < polygons->npolys; ++i) {
        polygons->areas[i] = 0;
        polygons->flags[i] = 1;
    }
    dtNavMeshCreateParams params = {};
    params.verts = polygons->verts;
    params.vertCount = polygons->nverts;
    params.polys = polygons->polys;
    params.polyAreas = polygons->areas;
    params.polyFlags = polygons->flags;
    params.polyCount = polygons->npolys;
    params.nvp = polygons->nvp;
    params.detailMeshes = detail->meshes;
    params.detailVerts = detail->verts;
    params.detailVertsCount = detail->nverts;
    params.detailTris = detail->tris;
    params.detailTriCount = detail->ntris;
    params.walkableHeight = settings->height;
    params.walkableRadius = settings->radius;
    params.walkableClimb = settings->maximumClimb;
    rcVcopy(params.bmin, polygons->bmin);
    rcVcopy(params.bmax, polygons->bmax);
    params.cs = config.cs;
    params.ch = config.ch;
    params.buildBvTree = true;
    int size = 0;
    if (!dtCreateNavMeshData(&params, bytes, &size)) return AE_NAV_BUILD_FAILED;
    *byteCount = size;
    *polygonCount = polygons->npolys;
    return AE_NAV_SUCCESS;
}
