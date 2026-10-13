import AdaUtils

/// Sent when a native window reports a different hinge angle or posture.
/// Subscribe through `EventManager` or `View.onEvent`, filtering by `windowID`
/// when several windows are active. A nil hinge means the display no longer
/// supplies hinge information.
public struct WindowHingeChanged: Event {
    public let windowID: UIWindow.ID
    public let previousHinge: DeviceHinge?
    public let hinge: DeviceHinge?

    /// Opening from zero to one hundred percent, or nil for an absent hinge.
    public var openingPercentage: Float? { hinge?.openingPercentage }

    public init(windowID: UIWindow.ID, previousHinge: DeviceHinge?, hinge: DeviceHinge?) {
        self.windowID = windowID
        self.previousHinge = previousHinge
        self.hinge = hinge
    }
}
