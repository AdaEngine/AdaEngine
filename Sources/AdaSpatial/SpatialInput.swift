import AdaECS
import Math

/// Stable input identity for hands and indirect system gestures.
public enum SpatialInteractor: Hashable, Sendable {
    case leftHand
    case rightHand
    case pointer(Int)
}

/// One active grip in world coordinates, expressed in meters.
public struct SpatialGrip: Sendable {
    public var interactor: SpatialInteractor
    public var pose: Transform3D
    /// A system-provided selection ray for distant interaction; nil uses direct proximity.
    public var ray: Ray?

    public init(interactor: SpatialInteractor, pose: Transform3D, ray: Ray? = nil) {
        self.interactor = interactor
        self.pose = pose
        self.ray = ray
    }
}

/// Replace before each frame. Missing grips release their objects, including on tracking loss.
public struct SpatialInput: Resource {
    public var grips: [SpatialGrip]

    public init(grips: [SpatialGrip] = []) {
        self.grips = grips
    }
}

/// Hysteresis avoids repeated grabs when fingertips fluctuate near the pinch threshold.
public struct SpatialPinchState: Sendable {
    public private(set) var isPinching = false

    public init() {}

    @discardableResult
    public mutating func update(distance: Float?, isTracked: Bool) -> Bool {
        guard isTracked, let distance, distance.isFinite, distance >= 0 else {
            isPinching = false
            return false
        }
        isPinching = distance < (isPinching ? 0.04 : 0.025)
        return isPinching
    }
}

/// Hand pose sampled from authorized hand tracking, independently from pinch state.
public struct SpatialHandPose: Sendable {
    public var interactor: SpatialInteractor
    public var pose: Transform3D
    public var palmNormal: Vector3
    public var isOpen: Bool

    public init(interactor: SpatialInteractor, pose: Transform3D, palmNormal: Vector3, isOpen: Bool) {
        self.interactor = interactor
        self.pose = pose
        self.palmNormal = palmNormal
        self.isOpen = isOpen
    }
}

/// Head and hand tracking in authored scene coordinates. Contains no raw eye-gaze data.
public struct SpatialTrackingFrame: Resource {
    public var head: Transform3D
    public var hands: [SpatialHandPose]

    public init(head: Transform3D = .identity, hands: [SpatialHandPose] = []) {
        self.head = head
        self.hands = hands
    }
}
