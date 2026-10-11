import AdaUI

/// Vector editor feedback drawn independently for each eye, after scene composition.
/// Coordinates use the supplied eye viewport in pixels; depth uses the camera's ordinary 0...1 clip range.
public struct ImmersiveOverlayDrawing {
    public var context: UIGraphicsContext
    public var depth: Float
    public var trackingIdentifier: UInt64?

    public init(context: UIGraphicsContext, depth: Float, trackingIdentifier: UInt64? = nil) {
        self.context = context
        self.depth = depth
        self.trackingIdentifier = trackingIdentifier
    }
}
