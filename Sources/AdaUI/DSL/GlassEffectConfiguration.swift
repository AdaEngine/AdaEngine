//
//  GlassEffectConfiguration.swift
//  AdaEngine
//

import AdaUtils

/// Configuration for the glass (blur + tint) effect applied to a view.
public struct Glass: Sendable {
    /// Corner radius of the glass shape in logical pixels. Default: 32.
    var cornerRadius: Float = 32.0
    /// Gaussian blur radius applied to the background, in logical pixels. Default: 8.
    var blurRadius: Float = 8.0
    /// Strength of the frosted glass tint [0, 1]. Default: 0.55.
    var glassTintStrength: Float = 0.8
    /// Strength of the edge shadow [0, 1]. Default: 0.01.
    var edgeShadowStrength: Float = 0.01
    /// Overall opacity of the glass surface [0, 1]. Default: 0.45.
    /// Lower values make the glass more transparent; 1.0 is fully opaque.
    var opacity: Float = 0.45
    /// Optional tint color blended over the glass surface. Alpha is multiplied by 0.3 in the shader.
    var tintColor: Color?

    public init() {}
}

extension Glass {

    /// Standard frosted glass: full blur and tinting. Mirrors Apple's `.regular`.
    public static var regular: Glass {
        return Glass()
    }

    /// Minimal glass: light blur, almost transparent. Mirrors Apple's `.clear`.
    public static var clear: Glass {
        var glass = Glass()
        glass.blurRadius = 2.5
        glass.glassTintStrength = 0.30
        glass.edgeShadowStrength = 0.0
        glass.opacity = 0.35
        return glass
    }

    /// No visible effect. Useful as an animation start/end state.
    public static var identity: Glass {
        var glass = Glass()
        glass.blurRadius = 0.0
        glass.glassTintStrength = 0.0
        glass.edgeShadowStrength = 0.0
        glass.opacity = 0.0
        return glass
    }

    public func tint(_ color: Color?) -> Glass {
        var newValue = self
        newValue.tintColor = color
        return newValue
    }

    public func opacity(_ opacity: Float) -> Glass {
        var newValue = self
        newValue.opacity = opacity
        return newValue
    }

    public func blurRadius(_ radius: Float) -> Glass {
        var newValue = self
        newValue.blurRadius = radius
        return newValue
    }

    public func glassTintStrength(_ strength: Float) -> Glass {
        var newValue = self
        newValue.glassTintStrength = strength
        return newValue
    }
}
