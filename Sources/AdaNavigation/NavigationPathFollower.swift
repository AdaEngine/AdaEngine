import Math

public enum NavigationMovementState: Equatable, Sendable {
    case idle
    case following
    case arrived
    /// Reached the end of a partial or search-limited path, not the requested goal.
    case partialEnd
    case blocked
}

/// Generates horizontal movement requests from a path and measured world-space positions.
/// Apply its output to a character mover; this type never changes a transform.
public struct NavigationPathFollower: Sendable {
    public var maximumSpeed: Float = 3
    public var brakingAcceleration: Float = 20
    public var waypointTolerance: Float = 0.05
    public var arrivalTolerance: Float = 0.15
    public var heightTolerance: Float = 0.3
    public var stuckTimeout: Float = 2

    public private(set) var state: NavigationMovementState = .idle
    public private(set) var path: NavigationRoute?
    public private(set) var nextWaypointIndex: Int = 0
    private var previousPosition: Vector3?
    private var stalledTime: Float = 0

    public init() {}

    /// Replaces any previous route and resets progress and stuck detection.
    public mutating func follow(_ path: NavigationRoute) {
        self.path = path
        nextWaypointIndex = min(1, max(0, path.points.count - 1))
        previousPosition = nil
        stalledTime = 0
        state = path.points.isEmpty ? .idle : .following
    }

    public mutating func cancel() {
        path = nil
        previousPosition = nil
        nextWaypointIndex = 0
        stalledTime = 0
        state = .idle
    }

    /// Call once per fixed tick using the actual position after the previous movement.
    /// A blocked follower stays stopped until a new route is supplied.
    public mutating func update(position: Vector3, deltaTime: Float) throws(NavigationError) -> Vector3 {
        guard position.x.isFinite, position.y.isFinite, position.z.isFinite,
            deltaTime.isFinite, deltaTime > 0,
            maximumSpeed.isFinite, maximumSpeed > 0,
            brakingAcceleration.isFinite, brakingAcceleration > 0,
            waypointTolerance.isFinite, waypointTolerance > 0,
            arrivalTolerance.isFinite, arrivalTolerance > 0,
            heightTolerance.isFinite, heightTolerance > 0,
            stuckTimeout.isFinite, stuckTimeout > 0 else { throw .invalidQuery }
        guard state == .following, let path, !path.points.isEmpty else { return .zero }
        let lastIndex = path.points.count - 1
        var offset = path.points[nextWaypointIndex] - position
        while nextWaypointIndex < lastIndex,
            horizontal(offset).length <= waypointTolerance, abs(offset.y) <= heightTolerance {
            nextWaypointIndex += 1
            offset = path.points[nextWaypointIndex] - position
        }
        let horizontalOffset = horizontal(offset)
        let distance = horizontalOffset.length
        if nextWaypointIndex == lastIndex, distance <= arrivalTolerance, abs(offset.y) <= heightTolerance {
            state = path.status == .complete ? .arrived : .partialEnd
            return .zero
        }
        if let previousPosition, (position - previousPosition).length < 0.001 {
            stalledTime += deltaTime
        } else {
            stalledTime = 0
        }
        previousPosition = position
        if stalledTime >= stuckTimeout {
            state = .blocked
            return .zero
        }
        guard distance > 0.0001 else { return .zero }
        // Stop at each corner instead of cutting across the polygon boundary.
        var speed = min(maximumSpeed, distance / deltaTime)
        let tolerance = nextWaypointIndex == lastIndex ? arrivalTolerance : waypointTolerance * 0.5
        let brakingDistance = max(0, distance - tolerance)
        speed = min(speed, (2 * brakingAcceleration * brakingDistance).squareRoot())
        return horizontalOffset / distance * speed
    }

    private func horizontal(_ value: Vector3) -> Vector3 {
        Vector3(value.x, 0, value.z)
    }
}
