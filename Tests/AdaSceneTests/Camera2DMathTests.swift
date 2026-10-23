import Foundation
import Math
import Testing

@testable import AdaScene

@Suite("Camera2D math")
struct Camera2DMathTests {
    @Test("Smoothing covers 63% in one time constant and composes across frame rates")
    func smoothing() {
        #expect(abs(Camera2DMath.smoothingFactor(deltaTime: 0.3, time: 0.3) - 0.632) < 0.001)
        #expect(Camera2DMath.smoothingFactor(deltaTime: 0.016, time: 0) == 1)
        #expect(Camera2DMath.smoothingFactor(deltaTime: 0, time: 0.3) == 0)
        #expect(Camera2DMath.smoothingFactor(deltaTime: -1, time: 0.3) == 0)
        #expect(Camera2DMath.smoothingFactor(deltaTime: 1, time: .nan) == 1)

        // Two short steps leave as much distance as one long step of the same total time.
        let first = Camera2DMath.smoothingFactor(deltaTime: 0.05, time: 0.4)
        let second = Camera2DMath.smoothingFactor(deltaTime: 0.15, time: 0.4)
        let whole = Camera2DMath.smoothingFactor(deltaTime: 0.2, time: 0.4)
        #expect(abs((1 - first) * (1 - second) - (1 - whole)) < 0.0001)
    }

    @Test("The dead zone moves the camera only as far as needed to keep the target inside")
    func deadZone() {
        let zone = Vector2(10, 4)
        #expect(Camera2DMath.applyDeadZone(position: .zero, target: Vector2(3, 1), deadZone: zone) == .zero)
        #expect(Camera2DMath.applyDeadZone(position: .zero, target: Vector2(8, 0), deadZone: zone) == Vector2(3, 0))
        #expect(Camera2DMath.applyDeadZone(position: .zero, target: Vector2(-9, -5), deadZone: zone) == Vector2(-4, -3))
        #expect(Camera2DMath.applyDeadZone(position: Vector2(10, 10), target: Vector2(10, 10), deadZone: .zero) == Vector2(10, 10))
        #expect(Camera2DMath.applyDeadZone(position: .zero, target: Vector2(4, 0), deadZone: Vector2(-5, -5)) == Vector2(4, 0))
    }

    @Test("Limits keep the whole visible area inside, at any zoom and viewport origin")
    func limits() {
        let min = Vector2(0, 0)
        let max = Vector2(400, 300)
        let centered = Camera2DMath.ViewExtents(viewportSize: Size(width: 100, height: 50), zoom: 1, viewportOrigin: Vector2(0.5, 0.5))
        #expect(centered == .init(viewportSize: Size(width: 100, height: 50), zoom: 1, viewportOrigin: [0.5, 0.5]))
        #expect(Camera2DMath.clamp(position: Vector2(10, 10), extents: centered, limitMin: min, limitMax: max) == Vector2(50, 25))
        #expect(Camera2DMath.clamp(position: Vector2(390, 290), extents: centered, limitMin: min, limitMax: max) == Vector2(350, 275))
        #expect(Camera2DMath.clamp(position: Vector2(200, 150), extents: centered, limitMin: min, limitMax: max) == Vector2(200, 150))

        // Zooming in shrinks the visible area, so the camera can get closer to the edge.
        let zoomed = Camera2DMath.ViewExtents(viewportSize: Size(width: 100, height: 50), zoom: 2, viewportOrigin: Vector2(0.5, 0.5))
        #expect(Camera2DMath.clamp(position: Vector2(10, 10), extents: zoomed, limitMin: min, limitMax: max) == Vector2(25, 12.5))

        // An origin in the corner puts the whole view on one side of the camera.
        let corner = Camera2DMath.ViewExtents(viewportSize: Size(width: 100, height: 50), zoom: 1, viewportOrigin: Vector2(0, 0))
        #expect(Camera2DMath.clamp(position: Vector2(-5, -5), extents: corner, limitMin: min, limitMax: max) == Vector2(0, 0))
        #expect(Camera2DMath.clamp(position: Vector2(390, 290), extents: corner, limitMin: min, limitMax: max) == Vector2(300, 250))

        // A view larger than the limits is centred on them instead of pinned to one edge.
        #expect(Camera2DMath.clamp(position: Vector2(0, 0), extents: centered, limitMin: Vector2(0, 0), limitMax: Vector2(60, 20)) == Vector2(30, 10))
        #expect(Camera2DMath.clamp(position: Vector2(0, 0), extents: corner, limitMin: Vector2(0, 0), limitMax: Vector2(60, 20)) == Vector2(-20, -15))
    }

    @Test("Shake scales with trauma squared, stays inside its bounds and is reproducible")
    func shake() {
        let none = Camera2DMath.shake(trauma: 0, time: 3, frequency: 25, maxOffset: Vector2(10, 10), maxRoll: 1)
        #expect(none.offset == .zero && none.roll == 0)
        #expect(Camera2DMath.shake(trauma: .nan, time: 3, frequency: 25, maxOffset: Vector2(10, 10), maxRoll: 1).offset == .zero)

        var largest: Float = 0
        for step in 0..<2000 {
            let time = Double(step) * 0.013
            let full = Camera2DMath.shake(trauma: 1, time: time, frequency: 25, maxOffset: Vector2(10, 6), maxRoll: 0.2)
            let half = Camera2DMath.shake(trauma: 0.5, time: time, frequency: 25, maxOffset: Vector2(10, 6), maxRoll: 0.2)
            #expect(abs(full.offset.x) <= 10 && abs(full.offset.y) <= 6 && abs(full.roll) <= 0.2)
            // Half the trauma is a quarter of the intensity, sample for sample.
            #expect(abs(half.offset.x - full.offset.x / 4) < 0.0001)
            #expect(abs(half.roll - full.roll / 4) < 0.0001)
            #expect(Camera2DMath.shake(trauma: 1, time: time, frequency: 25, maxOffset: Vector2(10, 6), maxRoll: 0.2).offset == full.offset)
            largest = max(largest, abs(full.offset.x))
        }
        // The noise really swings through most of its range instead of sitting near zero.
        #expect(largest > 6)
        #expect(abs(Camera2DMath.shake(trauma: 7, time: 1, frequency: 25, maxOffset: Vector2(10, 6), maxRoll: 0).offset.x) <= 10)
    }

    @Test("Pixel snapping rounds to the pixel grid of the current zoom")
    func pixelSnapping() {
        #expect(Camera2DMath.snapToPixels(Vector2(1.3, -0.74), zoom: 2) == Vector2(1.5, -0.5))
        #expect(Camera2DMath.snapToPixels(Vector2(1.3, 2.6), zoom: 1) == Vector2(1, 3))
        #expect(Camera2DMath.snapToPixels(Vector2(1.3, 2.6), zoom: 0) == Vector2(1.3, 2.6))
        #expect(Camera2DMath.snapToPixels(Vector2(1.3, 2.6), zoom: .nan) == Vector2(1.3, 2.6))
    }
}
