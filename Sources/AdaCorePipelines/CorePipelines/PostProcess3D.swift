import AdaAssets
import AdaRender
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

/// Darkens the image toward its corners. Applied to linear HDR before tone mapping.
public struct Vignette3D: Codable, Sendable, Equatable {
    /// Strength at the corners: `0` is off (the default), `1` fades the corners to black.
    public var intensity: Float
    /// Distance from the center, as a fraction of the distance to a corner, where darkening begins.
    public var radius: Float
    /// Width of the fade-in beyond `radius`, as a fraction of the corner distance.
    public var smoothness: Float

    public init(intensity: Float = 0, radius: Float = 0.75, smoothness: Float = 0.4) {
        self.intensity = intensity
        self.radius = radius
        self.smoothness = smoothness
    }

    private enum CodingKeys: CodingKey { case intensity, radius, smoothness }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Vignette3D()
        intensity = try container.decodeIfPresent(Float.self, forKey: .intensity) ?? defaults.intensity
        radius = try container.decodeIfPresent(Float.self, forKey: .radius) ?? defaults.radius
        smoothness = try container.decodeIfPresent(Float.self, forKey: .smoothness) ?? defaults.smoothness
    }

    var sanitized: Vignette3D {
        let defaults = Vignette3D()
        return Vignette3D(
            intensity: finiteRenderValue(intensity, fallback: defaults.intensity, range: 0...1),
            radius: finiteRenderValue(radius, fallback: defaults.radius, range: 0...2),
            smoothness: finiteRenderValue(smoothness, fallback: defaults.smoothness, range: 0.01...2)
        )
    }
}

/// Artistic color controls. `saturation` and `contrast` act on linear HDR before tone mapping; the optional
/// `lut` is applied to the display-referred color after tone mapping, so it can restyle the final look.
///
/// The LUT is a strip texture of `N` tiles side by side, each `N` by `N` pixels, so it is `N*N` wide and `N`
/// tall (for example 256 by 16 for `N = 16`). Red grows along x inside a tile, green grows down the rows
/// (row 0 is green 0), and blue selects the tile. It is sampled without sRGB decoding. An identity strip
/// leaves the image unchanged.
public struct ColorGrading3D: Codable, Sendable, Equatable {
    /// `1` is unchanged, `0` is grayscale, above `1` oversaturates.
    public var saturation: Float
    /// `1` is unchanged. Above `1` pushes values away from mid gray (0.18), below `1` pulls them toward it.
    public var contrast: Float
    /// Optional color lookup table in the strip layout above.
    public var lut: AssetHandle<Texture2D>?
    /// Blend between the graded and ungraded display color: `0` ignores the LUT, `1` applies it fully.
    public var lutIntensity: Float

    public init(saturation: Float = 1, contrast: Float = 1, lut: AssetHandle<Texture2D>? = nil, lutIntensity: Float = 1) {
        self.saturation = saturation
        self.contrast = contrast
        self.lut = lut
        self.lutIntensity = lutIntensity
    }

    private enum CodingKeys: CodingKey { case saturation, contrast, lut, lutIntensity }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ColorGrading3D()
        saturation = try container.decodeIfPresent(Float.self, forKey: .saturation) ?? defaults.saturation
        contrast = try container.decodeIfPresent(Float.self, forKey: .contrast) ?? defaults.contrast
        lut = try container.decodeIfPresent(AssetHandle<Texture2D>.self, forKey: .lut)
        lutIntensity = try container.decodeIfPresent(Float.self, forKey: .lutIntensity) ?? defaults.lutIntensity
    }

    /// Handles are compared by identity: two settings match when they share the same loaded handle.
    public static func == (lhs: ColorGrading3D, rhs: ColorGrading3D) -> Bool {
        lhs.saturation == rhs.saturation && lhs.contrast == rhs.contrast && lhs.lut === rhs.lut && lhs.lutIntensity == rhs.lutIntensity
    }

    var sanitized: ColorGrading3D {
        let defaults = ColorGrading3D()
        return ColorGrading3D(
            saturation: finiteRenderValue(saturation, fallback: defaults.saturation, range: 0...3),
            contrast: finiteRenderValue(contrast, fallback: defaults.contrast, range: 0.1...3),
            lut: lut,
            lutIntensity: finiteRenderValue(lutIntensity, fallback: defaults.lutIntensity, range: 0...1)
        )
    }

    /// The LUT texture to bind and the intensity to apply, or no LUT while the asset is missing or unloaded.
    var activeLUT: (texture: Texture2D, intensity: Float)? {
        let settings = sanitized
        guard settings.lutIntensity > 0, let texture = settings.lut?.asset else {
            return nil
        }
        return (texture, settings.lutIntensity)
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
    public var vignette: Vignette3D
    public var colorGrading: ColorGrading3D

    public init(
        exposureEV: Float = 0,
        bloom: Bloom3D = Bloom3D(),
        toneMapper: ToneMapper3D = ToneMapper3D.aces,
        vignette: Vignette3D = Vignette3D(),
        colorGrading: ColorGrading3D = ColorGrading3D()
    ) {
        self.exposureEV = exposureEV
        self.bloom = bloom
        self.toneMapper = toneMapper
        self.vignette = vignette
        self.colorGrading = colorGrading
    }

    private enum CodingKeys: CodingKey { case exposureEV, bloom, toneMapper, vignette, colorGrading }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exposureEV = try container.decodeIfPresent(Float.self, forKey: .exposureEV) ?? 0
        bloom = try container.decodeIfPresent(Bloom3D.self, forKey: .bloom) ?? Bloom3D()
        toneMapper = try container.decodeIfPresent(ToneMapper3D.self, forKey: .toneMapper) ?? ToneMapper3D.aces
        vignette = try container.decodeIfPresent(Vignette3D.self, forKey: .vignette) ?? Vignette3D()
        colorGrading = try container.decodeIfPresent(ColorGrading3D.self, forKey: .colorGrading) ?? ColorGrading3D()
    }

    /// Linear multiplier for `exposureEV`, limited to ±10 stops so a bad value cannot overflow half floats.
    var exposureScale: Float {
        Float(pow(2.0, Double(finiteRenderValue(exposureEV, fallback: 0, range: -10...10))))
    }
}
