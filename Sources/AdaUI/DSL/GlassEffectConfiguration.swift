//
//  GlassEffectConfiguration.swift
//  AdaEngine
//

/// Configuration for the glass (blur + tint) effect applied to a view.
public struct GlassEffectConfiguration: Sendable {
    /// Corner radius of the glass shape in logical pixels. Default: 32.
    public var cornerRadius: Float = 32.0
    /// Gaussian blur radius applied to the background, in logical pixels. Default: 8.
    public var blurRadius: Float = 8.0
    /// Strength of the frosted glass tint [0, 1]. Default: 0.55.
    public var glassTintStrength: Float = 0.8
    /// Strength of the edge shadow [0, 1]. Default: 0.01.
    public var edgeShadowStrength: Float = 0.01
    /// Overall opacity of the glass surface [0, 1]. Default: 0.45.
    /// Lower values make the glass more transparent; 1.0 is fully opaque.
    public var opacity: Float = 0.45

    public init() {}
}

/// Predefined glass effect styles.
public enum GlassEffectStyle: Sendable {
    /// Standard frosted glass: full blur and tinting. Mirrors Apple's `.regular`.
    case regular
    /// Minimal glass: light blur, almost transparent. Mirrors Apple's `.clear`.
    case clear
    /// No visible effect. Useful as an animation start/end state.
    case identity

    public var configuration: GlassEffectConfiguration {
        var c = GlassEffectConfiguration()
        switch self {
        case .regular:
            break
        case .clear:
            c.blurRadius = 2.5
            c.glassTintStrength = 0.30
            c.edgeShadowStrength = 0.0
            c.opacity = 0.35
        case .identity:
            c.blurRadius = 0.0
            c.glassTintStrength = 0.0
            c.edgeShadowStrength = 0.0
            c.opacity = 0.0
        }
        return c
    }
}
