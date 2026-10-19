import AdaUtils
import Math

/// Renders a camera at a fixed low resolution and presents it to the window or texture with nearest sampling.
///
/// The scene is drawn into a target of ``resolution`` pixels, so one world unit is one art pixel at zoom 1 and
/// the picture never depends on the window size. It is then scaled up by a whole number of device pixels and
/// centred, with the remaining border filled with ``letterboxColor``. User interface drawn by AdaUI is not part of
/// the low-resolution picture: it is drawn afterwards at the output's own resolution.
public struct PixelPerfectSettings: Codable, Equatable, Sendable {
    public enum ScaleMode: String, Codable, Sendable, CaseIterable {
        /// Scale by the largest whole number that fits. If the output is smaller than the resolution, the picture
        /// is scaled down to fit instead, which is no longer pixel exact.
        case integer
        /// Scale by the largest factor that fits, keeping the aspect ratio. Edges stay sharp but pixels can have uneven sizes.
        case fit
    }

    /// Largest accepted resolution per side. Larger targets are not pixel art and would waste memory.
    public static let maximumResolution = 4096

    /// Size of the low-resolution picture in pixels.
    public var resolution: SizeInt
    public var scaleMode: ScaleMode
    /// Colour of the border around the picture.
    public var letterboxColor: Color

    public init(resolution: SizeInt, scaleMode: ScaleMode = .integer, letterboxColor: Color = .black) {
        self.resolution = resolution
        self.scaleMode = scaleMode
        self.letterboxColor = letterboxColor
    }

    /// False for a zero, negative or absurdly large resolution. An invalid setting is ignored and the camera renders normally.
    public var isValid: Bool {
        (1...Self.maximumResolution).contains(resolution.width) && (1...Self.maximumResolution).contains(resolution.height)
    }
}

/// Where the low-resolution picture lands inside an output of a given size.
public struct PixelPerfectLayout: Equatable, Sendable {
    /// Output pixels per art pixel.
    public let scale: Float
    /// The picture in output pixels, from the top-left corner. Whole pixels when the scale is a whole number.
    public let rect: Rect

    /// Returns nil when the output has no area or the settings are invalid.
    public init?(settings: PixelPerfectSettings, outputSize: Size) {
        guard
            settings.isValid, outputSize.width.isFinite, outputSize.height.isFinite,
            outputSize.width > 0, outputSize.height > 0
        else {
            return nil
        }
        let fit = min(outputSize.width / Float(settings.resolution.width), outputSize.height / Float(settings.resolution.height))
        let scale: Float
        switch settings.scaleMode {
        case .fit:
            scale = fit
        case .integer:
            scale = fit >= 1 ? fit.rounded(.down) : fit
        }
        let width = Float(settings.resolution.width) * scale
        let height = Float(settings.resolution.height) * scale
        self.scale = scale
        self.rect = Rect(
            x: ((outputSize.width - width) / 2).rounded(.down),
            y: ((outputSize.height - height) / 2).rounded(.down),
            width: width,
            height: height
        )
    }

    /// Maps a point of the output to a point of the low-resolution picture, in art pixels from the top-left corner.
    /// Points in the border map outside `0 ..< resolution`.
    public func picturePoint(forOutputPoint point: Vector2) -> Vector2 {
        Vector2((point.x - rect.minX) / scale, (point.y - rect.minY) / scale)
    }
}

extension Camera {
    /// Size of the area the camera projects, in world units at zoom 1: the fixed resolution of a valid
    /// ``pixelPerfect`` setting, otherwise the logical viewport.
    public var projectionViewportSize: Size {
        if let pixelPerfect, pixelPerfect.isValid {
            return Size(width: Float(pixelPerfect.resolution.width), height: Float(pixelPerfect.resolution.height))
        }
        return logicalViewport.rect.size
    }

    /// Where the picture lands in the logical viewport, in logical points from the top-left corner.
    /// Nil when the camera is not pixel perfect or has no area yet.
    public var pixelPerfectPresentation: Rect? {
        guard let pixelPerfect else { return nil }
        let factor = computedData.targetScaleFactor > 0 ? computedData.targetScaleFactor : 1
        let physical = Size(width: logicalViewport.rect.size.width * factor, height: logicalViewport.rect.size.height * factor)
        guard let layout = PixelPerfectLayout(settings: pixelPerfect, outputSize: physical) else { return nil }
        return Rect(x: layout.rect.minX / factor, y: layout.rect.minY / factor, width: layout.rect.width / factor, height: layout.rect.height / factor)
    }

    /// Normalized device coordinates of a point in the logical viewport. A pixel-perfect camera measures against the
    /// picture rather than the whole viewport, so points in the border fall outside -1 ... 1.
    func ndc(forViewportPoint point: Vector2) -> Vector2 {
        let area = pixelPerfectPresentation ?? logicalViewport.rect
        guard area.width > 0, area.height > 0 else { return .zero }
        return Vector2((point.x - area.minX) * 2 / area.width - 1, (point.y - area.minY) * 2 / area.height - 1)
    }
}
