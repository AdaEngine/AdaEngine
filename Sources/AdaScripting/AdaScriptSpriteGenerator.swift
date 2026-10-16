import AdaAssets
import Foundation
import Gravity

/// A pixel-art image produced by an AdaScript generator.
public struct AdaScriptSpriteResult: Sendable {
    public let canvas: PixelCanvas
}

/// Runs an agent-authored AdaScript `build(sprite)` function in an isolated VM and collects the pixels it paints.
///
/// The script sees only the `sprite` builder (canvas size, palette and drawing calls) and the limits of
/// ``AdaScriptGeneratorRunner``. Encoding and writing the `.png` stay with the host (see ``PNGWriter``).
@MainActor
public enum AdaScriptSpriteGenerator {
    public static func generate(source: String) throws -> AdaScriptSpriteResult {
        let bridge = AdaScriptSpriteBridge()
        try AdaScriptGeneratorRunner.run(source: source, kind: "sprite", bridge: bridge, prelude: builderPrelude, factory: "__ada_make_sprite_builder")
        if let failure = bridge.failure { throw AdaScriptError.invalidManifest(failure) }
        return try bridge.result()
    }

    // Parameter validation lives in the bridge; the script-side wrapper only forwards positional values.
    private static let builderPrelude = """

        class __AdaSpriteBuilder {
            var __host;
            func init(host) { __host = host; }
            func size(width, height) { return __host.setSize(width, height); }
            func palette(index, red, green, blue) { return __host.setPalette(index, red, green, blue); }
            func opacity(index, alpha) { return __host.setOpacity(index, alpha); }
            func pixel(x, y, color) { return __host.paintPixel(x, y, color); }
            func fill(color) { return __host.paintFill(color); }
            func rect(x0, y0, x1, y1, color) {
                __host.stage(x0, y0);
                return __host.paintRect(x1, y1, color);
            }
            func line(x0, y0, x1, y1, color) {
                __host.stage(x0, y0);
                return __host.paintLine(x1, y1, color);
            }
            func ellipse(cx, cy, rx, ry, color) {
                __host.stage(cx, cy);
                return __host.paintEllipse(rx, ry, color);
            }
            func circle(cx, cy, radius, color) {
                __host.stage(cx, cy);
                return __host.paintEllipse(radius, radius, color);
            }
            func outline(color) { return __host.paintOutline(color); }
            func mirror() { return __host.mirrorHalf(); }
            func colorAt(x, y) { return __host.colorAt(x, y); }
        }
        func __ada_make_sprite_builder(host) { return __AdaSpriteBuilder(host); }
        """
}

// Only the owning main-actor generator touches this bridge, inside the shared VM lock.
@GSExportable("AdaSpriteBuilderHost")
final class AdaScriptSpriteBridge {
    @GSExportableIgnore var failure: String?
    @GSExportableIgnore private var canvas: PixelCanvas?
    @GSExportableIgnore private var staged = (0, 0)

    init() {}

    @GSExportableIgnore
    func result() throws -> AdaScriptSpriteResult {
        guard let canvas else { throw AdaScriptError.invalidManifest("The script never called sprite.size(width, height).") }
        guard canvas.opaquePixelCount > 0 else { throw AdaScriptError.invalidManifest("The script painted no pixels.") }
        return AdaScriptSpriteResult(canvas: canvas)
    }

    func setSize(width: GSValue, height: GSValue) -> Bool {
        guard canvas == nil else { return fail("sprite.size can be called once.") }
        guard let width = whole(width), let height = whole(height), let created = PixelCanvas(width: width, height: height) else {
            return fail("sprite.size expects a width and height in 1...\(PixelCanvas.maximumDimension).")
        }
        canvas = created
        return true
    }

    func setPalette(index: GSValue, red: GSValue, green: GSValue, blue: GSValue) -> Bool {
        guard canvas != nil else { return fail("Call sprite.size(width, height) first.") }
        guard let index = whole(index), (1...255).contains(index), let red = byte(red), let green = byte(green), let blue = byte(blue) else {
            return fail("sprite.palette expects an index in 1...255 and red, green, blue in 0...255.")
        }
        let alpha = canvas?.palette[index].alpha ?? 255
        canvas?.palette[index] = PixelColor(red: red, green: green, blue: blue, alpha: alpha)
        return true
    }

    func setOpacity(index: GSValue, alpha: GSValue) -> Bool {
        guard canvas != nil, let index = whole(index), (1...255).contains(index), let alpha = byte(alpha) else {
            return fail("sprite.opacity expects an index in 1...255 and an alpha in 0...255, after sprite.size.")
        }
        canvas?.palette[index].alpha = alpha
        return true
    }

    func paintPixel(x: GSValue, y: GSValue, color: GSValue) -> Bool {
        guard let x = whole(x), let y = whole(y), let color = byte(color), canvas != nil else { return fail("sprite.pixel expects x, y and a color in 0...255, after sprite.size.") }
        canvas?.set(x: x, y: y, color: color)
        return true
    }

    func paintFill(color: GSValue) -> Bool {
        guard let color = byte(color), canvas != nil else { return fail("sprite.fill expects a color in 0...255, after sprite.size.") }
        canvas?.fill(color: color)
        return true
    }

    /// Remembers the first two numbers of a shape call; Gravity bridge methods take at most four arguments.
    func stage(a: GSValue, b: GSValue) -> Bool {
        guard let a = whole(a), let b = whole(b) else { return fail("Shape coordinates must be whole numbers.") }
        staged = (a, b)
        return true
    }

    func paintRect(x1: GSValue, y1: GSValue, color: GSValue) -> Bool {
        guard failure == nil, canvas != nil, let x1 = whole(x1), let y1 = whole(y1), let color = byte(color) else {
            return fail("sprite.rect expects two inclusive corners as whole numbers and a color in 0...255, after sprite.size.")
        }
        canvas?.fillRect(x0: staged.0, y0: staged.1, x1: x1, y1: y1, color: color)
        return true
    }

    func paintLine(x1: GSValue, y1: GSValue, color: GSValue) -> Bool {
        guard failure == nil, canvas != nil, let x1 = whole(x1), let y1 = whole(y1), let color = byte(color) else {
            return fail("sprite.line expects two end points as whole numbers and a color in 0...255, after sprite.size.")
        }
        canvas?.line(x0: staged.0, y0: staged.1, x1: x1, y1: y1, color: color)
        return true
    }

    func paintEllipse(rx: GSValue, ry: GSValue, color: GSValue) -> Bool {
        guard failure == nil, canvas != nil, let rx = whole(rx), let ry = whole(ry), rx >= 0, ry >= 0, let color = byte(color) else {
            return fail("sprite.ellipse and sprite.circle expect a center, non-negative whole radii and a color in 0...255, after sprite.size.")
        }
        canvas?.fillEllipse(cx: staged.0, cy: staged.1, rx: rx, ry: ry, color: color)
        return true
    }

    func paintOutline(color: GSValue) -> Bool {
        guard let color = byte(color), color > 0, canvas != nil else { return fail("sprite.outline expects a color in 1...255, after sprite.size.") }
        canvas?.outline(color: color)
        return true
    }

    func mirrorHalf() -> Bool {
        guard canvas != nil else { return fail("Call sprite.size(width, height) first.") }
        canvas?.mirrorLeftToRight()
        return true
    }

    func colorAt(x: GSValue, y: GSValue) -> Int {
        guard let x = whole(x), let y = whole(y) else { return 0 }
        return Int(canvas?.color(x: x, y: y) ?? 0)
    }

    // MARK: - Helpers

    @GSExportableIgnore
    private func fail(_ message: String) -> Bool {
        failure = failure ?? message
        return false
    }

    @GSExportableIgnore
    private func whole(_ value: GSValue) -> Int? {
        guard let number = value.finiteNumber, number == number.rounded() else { return nil }
        return Int(number)
    }

    @GSExportableIgnore
    private func byte(_ value: GSValue) -> UInt8? {
        whole(value).flatMap { (0...255).contains($0) ? UInt8($0) : nil }
    }
}
