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

/// Per-camera controls applied to the linear HDR image before tone mapping. UI is never affected.
public struct PostProcess3D: Codable, Sendable, Equatable {
    /// Manual exposure compensation in stops (EV). `0` leaves the image unchanged; `+1` doubles brightness.
    public var exposureEV: Float
    public var bloom: Bloom3D

    public init(exposureEV: Float = 0, bloom: Bloom3D = Bloom3D()) {
        self.exposureEV = exposureEV
        self.bloom = bloom
    }

    private enum CodingKeys: CodingKey { case exposureEV, bloom }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exposureEV = try container.decodeIfPresent(Float.self, forKey: .exposureEV) ?? 0
        bloom = try container.decodeIfPresent(Bloom3D.self, forKey: .bloom) ?? Bloom3D()
    }

    /// Linear multiplier for `exposureEV`, limited to ±10 stops so a bad value cannot overflow half floats.
    var exposureScale: Float {
        Float(pow(2.0, Double(finiteRenderValue(exposureEV, fallback: 0, range: -10...10))))
    }
}
