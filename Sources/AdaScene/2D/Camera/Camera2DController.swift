import AdaECS
import Math

/// Marks an entity that a ``Camera2DController`` can follow.
///
/// Every entity of the controller's `targetGroup` counts, weighted by `weight`, so a camera can frame several players.
@Component
public struct CameraTarget2D: Codable, Sendable {
    /// Which controllers follow this entity. Empty is the default group.
    public var group: String
    /// Share of this entity in the weighted centre. Zero or negative weights are ignored.
    public var weight: Float

    @AdaScriptInit
    public init(group: String = "", weight: Float = 1) {
        self.group = group
        self.weight = weight
    }
}

/// Drives a 2D camera: follow, dead zone, smoothing, limits, zoom, shake and pixel snapping.
///
/// The controller owns the camera's XY position, and its Z rotation while roll shake is on, so move the camera through
/// ``position``/``snap(to:)`` and not through its `Transform`. Place the camera at the scene root: the controller writes
/// its world position directly after transform propagation, which keeps the view in step with the followed entities in
/// the same frame. Zoom is the orthographic `scale` (2 shows half the world area).
@Component
public struct Camera2DController: Codable, Sendable {
    public var isEnabled: Bool

    // MARK: Follow

    /// ``CameraTarget2D`` group to follow. Without any target the camera keeps its ``position``.
    public var targetGroup: String
    /// World-space offset from the followed point, e.g. to show more of what lies ahead.
    public var offset: Vector2
    /// Seconds to cover about 63% of the distance to the target. Zero follows instantly.
    public var smoothingTime: Float
    /// Width and height of the area around the camera centre in which the target can move without moving the camera.
    public var deadZone: Vector2
    /// Where the camera looks, before shake. Written by following; assign it (or use ``snap(to:)``) to move the camera by hand.
    public var position: Vector2

    // MARK: Limits

    /// Keeps the visible area inside ``limitMin`` ... ``limitMax``.
    public var limitsEnabled: Bool
    public var limitMin: Vector2
    public var limitMax: Vector2

    // MARK: Zoom

    /// Wanted zoom, clamped to ``minZoom`` ... ``maxZoom``.
    public var zoom: Float
    public var minZoom: Float
    public var maxZoom: Float
    /// Seconds to cover about 63% of the distance to ``zoom``. Zero zooms instantly.
    public var zoomSmoothingTime: Float

    // MARK: Shake

    /// Shake strength in 0...1. Raise it with ``addTrauma(_:)``; it falls back to zero at ``traumaDecay`` per second.
    public var trauma: Float
    public var traumaDecay: Float
    /// Largest shake displacement in world units, reached at full trauma.
    public var shakeMaxOffset: Vector2
    /// Largest shake roll in degrees at full trauma. Zero leaves the camera's rotation alone.
    public var shakeMaxRoll: Float
    /// Shake speed in cycles of the noise per second.
    public var shakeFrequency: Float

    // MARK: Presentation

    /// Rounds the final position to whole screen pixels so pixel art does not shimmer while the camera glides.
    public var snapsToPixels: Bool
    /// Increment to jump to the target on the next update instead of smoothing toward it.
    public var snapCount: Int

    var isInitialized = false
    var appliedSnapCount: Int
    var currentZoom: Float
    var shakeTime: Double = 0

    @AdaScriptInit
    public init(
        targetGroup: String = "",
        smoothingTime: Float = 0,
        zoom: Float = 1,
        isEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.targetGroup = targetGroup
        self.offset = .zero
        self.smoothingTime = smoothingTime
        self.deadZone = .zero
        self.position = .zero
        self.limitsEnabled = false
        self.limitMin = .zero
        self.limitMax = .zero
        self.zoom = zoom
        self.minZoom = 0.1
        self.maxZoom = 16
        self.zoomSmoothingTime = 0
        self.trauma = 0
        self.traumaDecay = 1
        self.shakeMaxOffset = Vector2(16, 16)
        self.shakeMaxRoll = 0
        self.shakeFrequency = 25
        self.snapsToPixels = false
        self.snapCount = 0
        self.appliedSnapCount = 0
        self.currentZoom = zoom
    }

    /// Adds shake. Strength stacks up to 1, so repeated hits build toward a full shake.
    public mutating func addTrauma(_ amount: Float) {
        guard amount.isFinite else { return }
        trauma = min(max(trauma + amount, 0), 1)
    }

    /// Moves the camera to `position` at once, without smoothing.
    public mutating func snap(to position: Vector2) {
        self.position = position
        isInitialized = true
        appliedSnapCount = snapCount
    }

    /// The zoom currently shown, which trails ``zoom`` while zoom smoothing is on.
    public var visibleZoom: Float { currentZoom }

    private enum CodingKeys: CodingKey {
        case isEnabled, targetGroup, offset, smoothingTime, deadZone, position
        case limitsEnabled, limitMin, limitMax
        case zoom, minZoom, maxZoom, zoomSmoothingTime
        case trauma, traumaDecay, shakeMaxOffset, shakeMaxRoll, shakeFrequency
        case snapsToPixels, snapCount
    }

    /// Scenes may carry only the fields they change.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            targetGroup: try values.decodeIfPresent(String.self, forKey: .targetGroup) ?? "",
            smoothingTime: try values.decodeIfPresent(Float.self, forKey: .smoothingTime) ?? 0,
            zoom: try values.decodeIfPresent(Float.self, forKey: .zoom) ?? 1,
            isEnabled: try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        )
        offset = try values.decodeIfPresent(Vector2.self, forKey: .offset) ?? offset
        deadZone = try values.decodeIfPresent(Vector2.self, forKey: .deadZone) ?? deadZone
        position = try values.decodeIfPresent(Vector2.self, forKey: .position) ?? position
        limitsEnabled = try values.decodeIfPresent(Bool.self, forKey: .limitsEnabled) ?? limitsEnabled
        limitMin = try values.decodeIfPresent(Vector2.self, forKey: .limitMin) ?? limitMin
        limitMax = try values.decodeIfPresent(Vector2.self, forKey: .limitMax) ?? limitMax
        minZoom = try values.decodeIfPresent(Float.self, forKey: .minZoom) ?? minZoom
        maxZoom = try values.decodeIfPresent(Float.self, forKey: .maxZoom) ?? maxZoom
        zoomSmoothingTime = try values.decodeIfPresent(Float.self, forKey: .zoomSmoothingTime) ?? zoomSmoothingTime
        trauma = try values.decodeIfPresent(Float.self, forKey: .trauma) ?? trauma
        traumaDecay = try values.decodeIfPresent(Float.self, forKey: .traumaDecay) ?? traumaDecay
        shakeMaxOffset = try values.decodeIfPresent(Vector2.self, forKey: .shakeMaxOffset) ?? shakeMaxOffset
        shakeMaxRoll = try values.decodeIfPresent(Float.self, forKey: .shakeMaxRoll) ?? shakeMaxRoll
        shakeFrequency = try values.decodeIfPresent(Float.self, forKey: .shakeFrequency) ?? shakeFrequency
        snapsToPixels = try values.decodeIfPresent(Bool.self, forKey: .snapsToPixels) ?? snapsToPixels
        snapCount = try values.decodeIfPresent(Int.self, forKey: .snapCount) ?? snapCount
        appliedSnapCount = snapCount
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(isEnabled, forKey: .isEnabled)
        try values.encode(targetGroup, forKey: .targetGroup)
        try values.encode(offset, forKey: .offset)
        try values.encode(smoothingTime, forKey: .smoothingTime)
        try values.encode(deadZone, forKey: .deadZone)
        try values.encode(position, forKey: .position)
        try values.encode(limitsEnabled, forKey: .limitsEnabled)
        try values.encode(limitMin, forKey: .limitMin)
        try values.encode(limitMax, forKey: .limitMax)
        try values.encode(zoom, forKey: .zoom)
        try values.encode(minZoom, forKey: .minZoom)
        try values.encode(maxZoom, forKey: .maxZoom)
        try values.encode(zoomSmoothingTime, forKey: .zoomSmoothingTime)
        try values.encode(trauma, forKey: .trauma)
        try values.encode(traumaDecay, forKey: .traumaDecay)
        try values.encode(shakeMaxOffset, forKey: .shakeMaxOffset)
        try values.encode(shakeMaxRoll, forKey: .shakeMaxRoll)
        try values.encode(shakeFrequency, forKey: .shakeFrequency)
        try values.encode(snapsToPixels, forKey: .snapsToPixels)
        try values.encode(snapCount, forKey: .snapCount)
    }
}
