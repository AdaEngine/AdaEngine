import Math

/// Dimensions in world units; Y is up and a position is the bottom of the agent.
public struct NavigationAgentSettings: Codable, Equatable, Sendable {
    public var radius: Float
    public var height: Float
    /// Degrees, in the range 0..<90.
    public var maximumSlope: Float
    /// Maximum traversable step. Recast also uses this for neighboring voxel heights on slopes.
    /// Zero is conservative; the character mover must support the configured traversal.
    public var maximumClimb: Float

    public init(radius: Float = 0.4, height: Float = 1.8, maximumSlope: Float = 45, maximumClimb: Float = 0) {
        self.radius = radius
        self.height = height
        self.maximumSlope = maximumSlope
        self.maximumClimb = maximumClimb
    }

    package var isValid: Bool {
        radius.isFinite && radius > 0 && height.isFinite && height >= radius * 2
            && maximumSlope.isFinite && maximumSlope >= 0 && maximumSlope < 90
            && maximumClimb.isFinite && maximumClimb >= 0 && maximumClimb < height
    }
}

/// An immutable bake. Use `encoded()` and `init(encoded:)` to persist a versioned asset.
/// Create through `NavigationMeshBaker` in the AdaNavigationBaking module.
public struct NavigationMeshData: Sendable {
    public let agent: NavigationAgentSettings
    public let polygonCount: Int
    package let bytes: [UInt8]

    package init(bytes: [UInt8], agent: NavigationAgentSettings, polygonCount: Int) {
        self.bytes = bytes
        self.agent = agent
        self.polygonCount = polygonCount
    }
}

public enum NavigationError: Error, Equatable, Sendable {
    case invalidGeometry
    case invalidSettings
    case emptyMesh
    case buildFailed
    case outOfMemory
    case invalidQuery
    case startOutsideMesh
    case targetOutsideMesh
    case unreachable
    case searchLimitReached
    case pathCapacityExceeded
    case queryFailed
    case invalidAsset
    case unsupportedAssetVersion
}

public enum NavigationPathStatus: Equatable, Sendable {
    case complete
    /// Ends at the closest reachable point found by the search.
    case partial
    /// The node budget was exhausted; the endpoint may not be the closest reachable point.
    case searchLimitReached
}

/// A polygon corridor and its funnel corners. References belong only to the queried mesh.
public struct NavigationRoute: Sendable {
    public let points: [Vector3]
    public let corridor: [UInt64]
    public let status: NavigationPathStatus

    public var length: Float {
        zip(points, points.dropFirst()).reduce(0) { $0 + ($1.1 - $1.0).length }
    }

    package init(points: [Vector3], corridor: [UInt64], status: NavigationPathStatus) {
        self.points = points
        self.corridor = corridor
        self.status = status
    }
}

/// Limits bound each query's search and temporary buffers; partial paths are opt-in.
public struct NavigationQueryOptions: Sendable {
    /// Half-extents of the start/end projection box. Keep Y small on stacked floors.
    public var projectionExtents: Vector3 = [1, 0.5, 1]
    /// Detour supports 4...65535 nodes. Smaller budgets are rejected.
    public var maximumNodes: Int = 2048
    public var maximumPolygons: Int = 4096
    public var maximumWaypoints: Int = 256
    public var allowsPartialPath: Bool = false
    public var includeFlags: UInt16 = .max
    public var excludeFlags: UInt16 = 0

    public init() {}

    package var isValid: Bool {
        projectionExtents.x.isFinite && projectionExtents.x > 0
            && projectionExtents.y.isFinite && projectionExtents.y > 0
            && projectionExtents.z.isFinite && projectionExtents.z > 0
            && (4...65535).contains(maximumNodes)
            && (1...65535).contains(maximumPolygons)
            && (2...65535).contains(maximumWaypoints)
    }
}
