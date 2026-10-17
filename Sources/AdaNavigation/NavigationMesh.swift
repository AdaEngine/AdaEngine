import CNavigation
import Math

/// Owns a Detour mesh and serializes access to its mutable query context.
/// Independent meshes can be queried concurrently. No native pointer escapes this actor.
public actor NavigationMesh {
    public nonisolated let data: NavigationMeshData
    private let storage: NavigationMeshStorage

    public init(data: NavigationMeshData) throws(NavigationError) {
        self.data = data
        self.storage = try NavigationMeshStorage(bytes: data.bytes)
    }

    /// Returns polygon fan vertices, three per triangle, for navigation debug overlays.
    public func debugTriangles() throws(NavigationError) -> [Vector3] {
        let count = unsafe ae_navigation_debug_triangles(storage.handle, nil, 0)
        guard count > 0 else { throw .invalidAsset }
        var values = [Float](repeating: 0, count: Int(count) * 3)
        let written = unsafe values.withUnsafeMutableBufferPointer { buffer in
            unsafe ae_navigation_debug_triangles(storage.handle, buffer.baseAddress, count)
        }
        guard written == count else { throw .invalidAsset }
        return (0..<Int(count)).map { Vector3(values[$0 * 3], values[$0 * 3 + 1], values[$0 * 3 + 2]) }
    }

    /// Projects both points onto the mesh, searches a corridor, and extracts funnel corners.
    /// This returns geometry; the caller remains responsible for physical movement.
    public func findPath(
        from start: Vector3,
        to target: Vector3,
        options: NavigationQueryOptions = NavigationQueryOptions()
    ) throws(NavigationError) -> NavigationRoute {
        guard options.isValid, isFinite(start), isFinite(target) else {
            throw .invalidQuery
        }
        var settings = AENavigationQuerySettings(
            extents: (options.projectionExtents.x, options.projectionExtents.y, options.projectionExtents.z),
            maximumNodes: Int32(options.maximumNodes),
            maximumPolygons: Int32(options.maximumPolygons),
            maximumWaypoints: Int32(options.maximumWaypoints),
            includeFlags: options.includeFlags,
            excludeFlags: options.excludeFlags
        )
        let startValues = [start.x, start.y, start.z]
        let targetValues = [target.x, target.y, target.z]
        var points = [Float](repeating: 0, count: options.maximumWaypoints * 3)
        var corridor = [UInt64](repeating: 0, count: options.maximumPolygons)
        var pointCount: Int32 = 0
        var polygonCount: Int32 = 0
        let result = unsafe startValues.withUnsafeBufferPointer { startBuffer in
            unsafe targetValues.withUnsafeBufferPointer { targetBuffer in
                unsafe points.withUnsafeMutableBufferPointer { pointBuffer in
                    unsafe corridor.withUnsafeMutableBufferPointer { corridorBuffer in
                        unsafe ae_navigation_find_path(
                            storage.handle, startBuffer.baseAddress, targetBuffer.baseAddress,
                            &settings, pointBuffer.baseAddress, corridorBuffer.baseAddress, &pointCount, &polygonCount
                        )
                    }
                }
            }
        }
        let status: NavigationPathStatus
        switch Int64(result) {
        case Int64(AE_NAV_SUCCESS.rawValue):
            status = .complete
        case Int64(AE_NAV_PARTIAL.rawValue):
            guard options.allowsPartialPath else { throw .unreachable }
            status = .partial
        case Int64(AE_NAV_SEARCH_LIMIT.rawValue):
            guard options.allowsPartialPath else { throw .searchLimitReached }
            status = .searchLimitReached
        case Int64(AE_NAV_START_OUTSIDE.rawValue): throw .startOutsideMesh
        case Int64(AE_NAV_TARGET_OUTSIDE.rawValue): throw .targetOutsideMesh
        case Int64(AE_NAV_OUT_OF_MEMORY.rawValue): throw .outOfMemory
        case Int64(AE_NAV_BUFFER_LIMIT.rawValue): throw .pathCapacityExceeded
        case Int64(AE_NAV_INVALID_INPUT.rawValue): throw .invalidQuery
        default: throw .queryFailed
        }
        let corners = (0..<Int(pointCount)).map { index in
            Vector3(points[index * 3], points[index * 3 + 1], points[index * 3 + 2])
        }
        return NavigationRoute(points: corners, corridor: Array(corridor.prefix(Int(polygonCount))), status: status)
    }

    private func isFinite(_ value: Vector3) -> Bool {
        value.x.isFinite && value.y.isFinite && value.z.isFinite
    }
}

/// Used only by NavigationMesh's actor; destruction releases the mesh and query together.
@safe
private final class NavigationMeshStorage {
    let handle: OpaquePointer

    init(bytes: [UInt8]) throws(NavigationError) {
        guard !bytes.isEmpty, bytes.count <= Int(Int32.max) else { throw .emptyMesh }
        let result = unsafe bytes.withUnsafeBufferPointer { buffer in
            unsafe ae_navigation_create(buffer.baseAddress, Int32(buffer.count))
        }
        guard let result = unsafe result else { throw .outOfMemory }
        unsafe self.handle = result
    }

    deinit {
        unsafe ae_navigation_destroy(handle)
    }
}
