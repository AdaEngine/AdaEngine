import AdaCorePipelines
@testable import AdaUI
import Math
import Testing

@MainActor
struct GlassBackgroundCaptureTests {
    @Test
    func captureIncludesBlurAndRefractionWithoutCopyingTheWholeTarget() {
        let vertices = UITessellator().tessellateGlassQuad(
            transform: Transform3D(translation: [200, -200, 0], rotation: Quat(axis: [0, 0, 1], angle: 0), scale: [200, 80, 1]),
            halfSize: [100, 40],
            configuration: .regular,
            scaleFactor: 3
        )
        let rect = GlassBackgroundCapture.region(
            vertices: vertices,
            viewport: Rect(x: 0, y: 0, width: 1200, height: 2400),
            scaleFactor: 3,
            textureSize: [1200, 2400]
        )
        #expect(rect.minX < 300 - 42)
        #expect(rect.maxX > 900 + 42)
        #expect(rect.minY < 480 - 42)
        #expect(rect.maxY > 720 + 42)
        #expect(rect.width * rect.height < 1200 * 2400 / 4)
    }

    @Test
    func captureClampsRotatedAndEdgeGlassToTheTexture() {
        let vertices = UITessellator().tessellateGlassQuad(
            transform: Transform3D(translation: [5, -5, 0], rotation: Quat(axis: [0, 0, 1], angle: .pi / 4), scale: [120, 60, 1]),
            halfSize: [60, 30],
            configuration: .regular.dispersionStrength(1),
            scaleFactor: 2
        )
        let rect = GlassBackgroundCapture.region(
            vertices: vertices,
            viewport: Rect(x: 0, y: 0, width: 400, height: 800),
            scaleFactor: 2,
            textureSize: [400, 800]
        )
        #expect(rect.minX == 0)
        #expect(rect.minY == 0)
        #expect(rect.maxX <= 400)
        #expect(rect.maxY <= 800)
        #expect(rect.maxX > 100)
    }

    @Test
    func invalidGeometryFallsBackToACompleteSnapshot() {
        let vertices = UITessellator().tessellateGlassQuad(
            transform: .identity, halfSize: [10, 10], configuration: .regular.blurRadius(.infinity), scaleFactor: 1
        )
        #expect(GlassBackgroundCapture.region(
            vertices: vertices,
            viewport: Rect(x: 0, y: 0, width: 400, height: 800),
            scaleFactor: 1,
            textureSize: [400, 800]
        ) == Rect(x: 0, y: 0, width: 400, height: 800))
    }
}
