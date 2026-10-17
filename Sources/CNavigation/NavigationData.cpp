#include "CNavigation.h"
#include "DetourNavMesh.h"
#include <cmath>
#include <cstring>
#include <cstdint>

namespace {
template <typename T> T read(const uint8_t *bytes, int64_t offset) {
    T value;
    std::memcpy(&value, bytes + offset, sizeof(T));
    return value;
}
int64_t aligned(int64_t size) { return (size + 3) & ~int64_t(3); }
}

// This format is pinned to Detour 1.6.0, 32-bit polygon references, little-endian.
// Do not pass a tile from disk to dtNavMesh::init without these structural checks.
int32_t ae_navigation_validate(const uint8_t *bytes, int32_t count,
    AENavigationBuildSettings *agent, int32_t *polygonCount) {
    static_assert(sizeof(dtPolyRef) == 4, "Update the persisted navigation format for 64-bit references");
    if (!bytes || count < static_cast<int32_t>(sizeof(dtMeshHeader)) || count > 64 * 1024 * 1024) return 0;
    const auto header = read<dtMeshHeader>(bytes, 0);
    if (header.magic != DT_NAVMESH_MAGIC || header.version != DT_NAVMESH_VERSION ||
        header.x != 0 || header.y != 0 || header.layer != 0 ||
        header.polyCount < 1 || header.polyCount >= 32768 || header.vertCount < 3 || header.vertCount >= 65535 ||
        header.maxLinkCount < 1 || header.maxLinkCount > header.polyCount * DT_VERTS_PER_POLYGON ||
        header.detailMeshCount != header.polyCount || header.detailVertCount < 0 ||
        header.detailTriCount < 1 || header.bvNodeCount < 0 || header.bvNodeCount > header.polyCount * 2 ||
        header.offMeshConCount != 0 || header.offMeshBase != header.polyCount) return 0;
    if (!std::isfinite(header.walkableRadius) || header.walkableRadius <= 0 ||
        !std::isfinite(header.walkableHeight) || header.walkableHeight < header.walkableRadius * 2 ||
        !std::isfinite(header.walkableClimb) || header.walkableClimb < 0 ||
        !std::isfinite(header.bvQuantFactor) || header.bvQuantFactor <= 0) return 0;
    for (int i = 0; i < 3; ++i) {
        if (!std::isfinite(header.bmin[i]) || !std::isfinite(header.bmax[i]) || header.bmax[i] < header.bmin[i]) return 0;
    }
    const int64_t vertices = aligned(sizeof(dtMeshHeader));
    const int64_t polygons = vertices + aligned(int64_t(header.vertCount) * 3 * sizeof(float));
    const int64_t links = polygons + aligned(int64_t(header.polyCount) * sizeof(dtPoly));
    const int64_t details = links + aligned(int64_t(header.maxLinkCount) * sizeof(dtLink));
    const int64_t detailVertices = details + aligned(int64_t(header.detailMeshCount) * sizeof(dtPolyDetail));
    const int64_t detailTriangles = detailVertices + aligned(int64_t(header.detailVertCount) * 3 * sizeof(float));
    const int64_t tree = detailTriangles + aligned(int64_t(header.detailTriCount) * 4);
    const int64_t end = tree + aligned(int64_t(header.bvNodeCount) * sizeof(dtBVNode));
    if (end != count) return 0;
    for (int64_t i = 0; i < int64_t(header.vertCount) * 3; ++i)
        if (!std::isfinite(read<float>(bytes, vertices + i * sizeof(float)))) return 0;
    for (int64_t i = 0; i < int64_t(header.detailVertCount) * 3; ++i)
        if (!std::isfinite(read<float>(bytes, detailVertices + i * sizeof(float)))) return 0;

    int edgeCount = 0;
    for (int i = 0; i < header.polyCount; ++i) {
        const auto polygon = read<dtPoly>(bytes, polygons + int64_t(i) * sizeof(dtPoly));
        if (polygon.getType() != DT_POLYTYPE_GROUND || polygon.vertCount < 3 || polygon.vertCount > DT_VERTS_PER_POLYGON) return 0;
        edgeCount += polygon.vertCount;
        for (int j = 0; j < polygon.vertCount; ++j) {
            if (polygon.verts[j] >= header.vertCount) return 0;
            for (int k = 0; k < j; ++k) if (polygon.verts[j] == polygon.verts[k]) return 0;
            const unsigned int neighbor = polygon.neis[j];
            if (neighbor == 0) continue;
            // Only internal single-tile connections are supported by this file version.
            if (neighbor > static_cast<unsigned int>(header.polyCount) || neighbor == static_cast<unsigned int>(i + 1)) return 0;
            const auto other = read<dtPoly>(bytes, polygons + int64_t(neighbor - 1) * sizeof(dtPoly));
            if (other.vertCount < 3 || other.vertCount > DT_VERTS_PER_POLYGON) return 0;
            bool reciprocal = false;
            for (int k = 0; k < other.vertCount; ++k) {
                if (other.neis[k] == i + 1 && other.verts[k] == polygon.verts[(j + 1) % polygon.vertCount] &&
                    other.verts[(k + 1) % other.vertCount] == polygon.verts[j]) reciprocal = true;
            }
            if (!reciprocal) return 0;
        }
        const auto detail = read<dtPolyDetail>(bytes, details + int64_t(i) * sizeof(dtPolyDetail));
        if (int64_t(detail.vertBase) + detail.vertCount > header.detailVertCount ||
            int64_t(detail.triBase) + detail.triCount > header.detailTriCount || detail.triCount == 0) return 0;
        for (int j = 0; j < detail.triCount; ++j) {
            const auto triangle = bytes + detailTriangles + (int64_t(detail.triBase) + j) * 4;
            for (int k = 0; k < 3; ++k) if (triangle[k] >= polygon.vertCount + detail.vertCount) return 0;
        }
    }
    if (header.maxLinkCount < edgeCount) return 0;
    for (int i = 0; i < header.bvNodeCount; ++i) {
        const auto node = read<dtBVNode>(bytes, tree + int64_t(i) * sizeof(dtBVNode));
        for (int j = 0; j < 3; ++j) if (node.bmin[j] > node.bmax[j]) return 0;
        if (node.i >= header.polyCount || (node.i < 0 && -int64_t(node.i) > header.bvNodeCount - i)) return 0;
    }
    if (agent) {
        *agent = {};
        agent->radius = header.walkableRadius;
        agent->height = header.walkableHeight;
        agent->maximumClimb = header.walkableClimb;
    }
    if (polygonCount) *polygonCount = header.polyCount;
    return 1;
}
