import Foundation

/// HDR bloom. Bright scene energy above `threshold` is blurred through a downsample/upsample chain and added
/// to the image before tone mapping, so it follows exposure and is clipped by the tone mapper like any light.
///
/// Bloom is built from the lit geometry. Pixels that only show the skybox do not contribute energy, though
/// bloom from geometry still spreads over them.
public struct Bloom3D: Codable, Sendable, Equatable {
    /// Whether the bloom chain is built and composited. Off by default; a disabled bloom allocates nothing.
    public var isEnabled: Bool
    /// Strength of the added glow. Typical values are `0.05...0.5`.
    public var intensity: Float
    /// Exposed scene luminance where bloom starts, in linear HDR units. `1` is display white before tone mapping.
    public var threshold: Float
    /// Width of the soft transition below `threshold`, as a fraction of it (`0...1`).
    public var softKnee: Float
    /// How strongly each wider level contributes (`0...1`). Higher values give a larger, softer glow.
    public var scatter: Float

    public init(isEnabled: Bool = false, intensity: Float = 0.2, threshold: Float = 1, softKnee: Float = 0.5, scatter: Float = 0.7) {
        self.isEnabled = isEnabled
        self.intensity = intensity
        self.threshold = threshold
        self.softKnee = softKnee
        self.scatter = scatter
    }

    private enum CodingKeys: CodingKey { case isEnabled, intensity, threshold, softKnee, scatter }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Bloom3D()
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        intensity = try container.decodeIfPresent(Float.self, forKey: .intensity) ?? defaults.intensity
        threshold = try container.decodeIfPresent(Float.self, forKey: .threshold) ?? defaults.threshold
        softKnee = try container.decodeIfPresent(Float.self, forKey: .softKnee) ?? defaults.softKnee
        scatter = try container.decodeIfPresent(Float.self, forKey: .scatter) ?? defaults.scatter
    }

    /// Settings clamped to ranges the shaders handle, replacing non-finite values with defaults.
    var sanitized: Bloom3D {
        let defaults = Bloom3D()
        return Bloom3D(
            isEnabled: isEnabled,
            intensity: finiteRenderValue(intensity, fallback: defaults.intensity, range: 0...4),
            threshold: finiteRenderValue(threshold, fallback: defaults.threshold, range: 0...64),
            softKnee: finiteRenderValue(softKnee, fallback: defaults.softKnee, range: 0...1),
            scatter: finiteRenderValue(scatter, fallback: defaults.scatter, range: 0...1)
        )
    }
}

/// Curve that maps linear HDR scene color to the displayable range, applied once after exposure and bloom.
public enum ToneMapper3D: String, Codable, Sendable, CaseIterable {
    /// ACES filmic fit. The original and default look: strong contrast, hue shifts in saturated highlights.
    case aces
    /// Khronos PBR Neutral. Leaves colors below the compression point nearly untouched, so authored
    /// base colors and textures read as designed; highlights roll off and desaturate gently.
    case neutral
    /// No curve. Values above `1` clip to white, which is useful for checking raw energy.
    case none

    /// Shader selector shared with `Tonemapping.glsl`. `aces` stays `0` so unset data keeps the old output.
    var shaderMode: Float {
        switch self {
        case .aces: 0
        case .neutral: 1
        case .none: 2
        }
    }
}

/// Per-camera controls applied to the linear HDR image before and during tone mapping. UI is never affected.
public struct PostProcess3D: Codable, Sendable, Equatable {
    /// Manual exposure compensation in stops (EV). `0` leaves the image unchanged; `+1` doubles brightness.
    public var exposureEV: Float
    public var bloom: Bloom3D
    /// Tone-mapping curve. Defaults to ``ToneMapper3D/aces``, the behavior before this setting existed.
    public var toneMapper: ToneMapper3D

    public init(exposureEV: Float = 0, bloom: Bloom3D = Bloom3D(), toneMapper: ToneMapper3D = ToneMapper3D.aces) {
        self.exposureEV = exposureEV
        self.bloom = bloom
        self.toneMapper = toneMapper
    }

    private enum CodingKeys: CodingKey { case exposureEV, bloom, toneMapper }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exposureEV = try container.decodeIfPresent(Float.self, forKey: .exposureEV) ?? 0
        bloom = try container.decodeIfPresent(Bloom3D.self, forKey: .bloom) ?? Bloom3D()
        toneMapper = try container.decodeIfPresent(ToneMapper3D.self, forKey: .toneMapper) ?? ToneMapper3D.aces
    }

    /// Linear multiplier for `exposureEV`, limited to ±10 stops so a bad value cannot overflow half floats.
    var exposureScale: Float {
        Float(pow(2.0, Double(finiteRenderValue(exposureEV, fallback: 0, range: -10...10))))
    }
}
