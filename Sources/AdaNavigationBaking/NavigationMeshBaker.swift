import AdaNavigation
import CNavigationBaking
import Math

/// Single-tile bake settings. Cell dimensions control accuracy, memory and build time.
public struct NavigationBakeSettings: Sendable {
    public var agent: NavigationAgentSettings
    public var cellSize: Float
    public var cellHeight: Float
    /// Upper bound on the XZ raster dimensions' product before allocating the heightfield.
    public var maximumGridCells: Int

    public init(
        agent: NavigationAgentSettings = NavigationAgentSettings(),
        cellSize: Float = 0.2,
        cellHeight: Float = 0.1,
        maximumGridCells: Int = 4_000_000
    ) {
        self.agent = agent
        self.cellSize = cellSize
        self.cellHeight = cellHeight
        self.maximumGridCells = maximumGridCells
    }
}

public enum NavigationMeshBaker {
    /// Builds from world-space triangles with upward-facing winding on walkable surfaces.
    /// Include walls and ceilings as well as floors. Geometry and all buffers are copied.
    /// Executes on the concurrent executor so baking does not block the main actor.
    @concurrent
    public static func bake(
        vertices: [Vector3],
        indices: [UInt32],
        settings: NavigationBakeSettings = NavigationBakeSettings()
    ) async throws(NavigationError) -> NavigationMeshData {
        guard settings.agent.isValid,
            settings.cellSize.isFinite, settings.cellSize > 0,
            settings.cellHeight.isFinite, settings.cellHeight > 0,
            settings.maximumGridCells > 0, settings.maximumGridCells <= Int(Int32.max) else {
            throw .invalidSettings
        }
        guard vertices.count >= 3, vertices.count <= Int(Int32.max) / 3,
            !indices.isEmpty, indices.count.isMultiple(of: 3), indices.count <= Int(Int32.max),
            vertices.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }),
            indices.allSatisfy({ $0 < vertices.count }) else {
            throw .invalidGeometry
        }
        let positions = vertices.flatMap { [$0.x, $0.y, $0.z] }
        let triangles = indices.map(Int32.init)
        var nativeSettings = AENavigationBuildSettings(
            radius: settings.agent.radius,
            height: settings.agent.height,
            maximumSlope: settings.agent.maximumSlope,
            maximumClimb: settings.agent.maximumClimb,
            cellSize: settings.cellSize,
            cellHeight: settings.cellHeight,
            maximumGridCells: Int32(settings.maximumGridCells)
        )
        var bytes: UnsafeMutablePointer<UInt8>?
        var byteCount: Int32 = 0
        var polygonCount: Int32 = 0
        let result = unsafe positions.withUnsafeBufferPointer { positionBuffer in
            unsafe triangles.withUnsafeBufferPointer { triangleBuffer in
                unsafe ae_navigation_bake(
                    positionBuffer.baseAddress, Int32(vertices.count), triangleBuffer.baseAddress, Int32(indices.count / 3),
                    &nativeSettings, &bytes, &byteCount, &polygonCount
                )
            }
        }
        guard result == AE_NAV_SUCCESS.rawValue, let bytes = unsafe bytes else {
            switch result {
            case AE_NAV_INVALID_INPUT.rawValue: throw .invalidSettings
            case AE_NAV_OUT_OF_MEMORY.rawValue: throw .outOfMemory
            case AE_NAV_EMPTY_MESH.rawValue: throw .emptyMesh
            default: throw .buildFailed
            }
        }
        defer { unsafe ae_navigation_free_bytes(bytes) }
        let copy = unsafe Array(UnsafeBufferPointer(start: bytes, count: Int(byteCount)))
        return NavigationMeshData(bytes: copy, agent: settings.agent, polygonCount: Int(polygonCount))
    }
}
