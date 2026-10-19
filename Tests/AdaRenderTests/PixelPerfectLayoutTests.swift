@_spi(Internal) import AdaRender
import AdaUtils
import Foundation
import Math
import Testing

@Suite("Pixel perfect layout")
struct PixelPerfectLayoutTests {
    private let resolution = SizeInt(width: 320, height: 180)

    private func makeLayout(_ output: Size, mode: PixelPerfectSettings.ScaleMode = .integer, resolution: SizeInt? = nil) -> PixelPerfectLayout? {
        PixelPerfectLayout(settings: PixelPerfectSettings(resolution: resolution ?? self.resolution, scaleMode: mode), outputSize: output)
    }

    @Test("Integer mode picks the largest whole scale that fits and centres the picture on whole pixels")
    func integerScale() throws {
        // 1920x1080 is exactly 6x of 320x180.
        let exact = try #require(makeLayout(Size(width: 1920, height: 1080)))
        #expect(exact.scale == 6)
        #expect(exact.rect == Rect(x: 0, y: 0, width: 1920, height: 1080))

        // 1366x768: height allows 4.26, width 4.27, so 4x with borders on all sides.
        let laptop = try #require(makeLayout(Size(width: 1366, height: 768)))
        #expect(laptop.scale == 4)
        #expect(laptop.rect == Rect(x: 43, y: 24, width: 1280, height: 720))

        // A tall window is limited by its width.
        let tall = try #require(makeLayout(Size(width: 700, height: 1600)))
        #expect(tall.scale == 2)
        #expect(tall.rect == Rect(x: 30, y: 620, width: 640, height: 360))
    }

    @Test("Odd borders round down so the picture never lands on half a pixel")
    func borderRounding() throws {
        let layout = try #require(makeLayout(Size(width: 641, height: 361)))
        #expect(layout.scale == 2)
        #expect(layout.rect.minX == 0 && layout.rect.minY == 0) // 1-pixel remainders: floor(0.5) = 0
        #expect(layout.rect.minX == layout.rect.minX.rounded() && layout.rect.minY == layout.rect.minY.rounded())
    }

    @Test("Fit mode fills the output along its limiting axis with a fractional scale")
    func fitScale() throws {
        let fit = try #require(makeLayout(Size(width: 1000, height: 1000), mode: .fit))
        #expect(fit.scale == 3.125)
        #expect(fit.rect.width == 1000)
        #expect(fit.rect.height == 562.5)
        #expect(fit.rect.minY == 218)
    }

    @Test("An output smaller than the resolution scales down to fit instead of cropping")
    func smallerOutput() throws {
        let layout = try #require(makeLayout(Size(width: 160, height: 90)))
        #expect(layout.scale == 0.5)
        #expect(layout.rect == Rect(x: 0, y: 0, width: 160, height: 90))
    }

    @Test("Settings and outputs that cannot produce a picture give no layout")
    func rejections() {
        #expect(makeLayout(Size(width: 0, height: 100)) == nil)
        #expect(makeLayout(Size(width: 100, height: -1)) == nil)
        #expect(makeLayout(Size(width: .nan, height: 100)) == nil)
        #expect(makeLayout(Size(width: 100, height: .infinity)) == nil)
        #expect(makeLayout(Size(width: 100, height: 100), resolution: SizeInt(width: 0, height: 10)) == nil)
        #expect(makeLayout(Size(width: 100, height: 100), resolution: SizeInt(width: 10, height: -3)) == nil)
        #expect(makeLayout(Size(width: 100, height: 100), resolution: SizeInt(width: 100_000, height: 10)) == nil)
        #expect(!PixelPerfectSettings(resolution: SizeInt(width: 0, height: 0)).isValid)
        #expect(PixelPerfectSettings(resolution: SizeInt(width: 4096, height: 1)).isValid)
        #expect(!PixelPerfectSettings(resolution: SizeInt(width: 4097, height: 1)).isValid)
    }

    @Test("Output points map back to art pixels, with the border mapping outside the picture")
    func picturePoints() throws {
        let layout = try #require(makeLayout(Size(width: 1366, height: 768)))
        #expect(layout.picturePoint(forOutputPoint: Vector2(43, 24)) == Vector2(0, 0))
        #expect(layout.picturePoint(forOutputPoint: Vector2(43 + 1280, 24 + 720)) == Vector2(320, 180))
        #expect(layout.picturePoint(forOutputPoint: Vector2(43 + 6, 24 + 10)) == Vector2(1.5, 2.5))
        #expect(layout.picturePoint(forOutputPoint: Vector2(0, 0)).x < 0)
    }

    @Test("A camera reports where its picture lands in logical points, accounting for the display scale")
    func cameraPresentation() throws {
        var camera = Camera()
        #expect(camera.pixelPerfectPresentation == nil)
        camera.pixelPerfect = PixelPerfectSettings(resolution: resolution)
        camera.logicalViewport.rect = Rect(x: 0, y: 0, width: 683, height: 384)
        camera.computedData.targetScaleFactor = 2 // a 1366x768 pixel output
        let presentation = try #require(camera.pixelPerfectPresentation)
        #expect(presentation == Rect(x: 21.5, y: 12, width: 640, height: 360))
        #expect(camera.projectionViewportSize == Size(width: 320, height: 180))

        camera.pixelPerfect = PixelPerfectSettings(resolution: SizeInt(width: 0, height: 5))
        #expect(camera.projectionViewportSize == camera.logicalViewport.rect.size, "an invalid setting is ignored")
        camera.pixelPerfect = nil
        #expect(camera.pixelPerfectPresentation == nil)
    }

    @Test("Settings survive Codable")
    func coding() throws {
        let settings = PixelPerfectSettings(resolution: SizeInt(width: 256, height: 144), scaleMode: .fit, letterboxColor: Color(red: 0.1, green: 0.2, blue: 0.3))
        let copy = try JSONDecoder().decode(PixelPerfectSettings.self, from: JSONEncoder().encode(settings))
        #expect(copy == settings)
    }
}
