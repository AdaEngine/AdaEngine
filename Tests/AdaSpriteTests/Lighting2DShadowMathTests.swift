//
//  Lighting2DShadowMathTests.swift
//  AdaEngine
//

import AdaSprite
import Math
import Testing

@Suite("Lighting2DShadowMath")
struct Lighting2DShadowMathTests {

    @Test
    func shadowFinQuads_emptyPolygon() {
        let quads = Lighting2DShadowMath.shadowFinQuads(lightWorld: .zero, polygonWorldCCW: [])
        #expect(quads.isEmpty)
    }

    @Test
    func shadowFinQuads_squareContainsLight() {
        let square: [Vector2] = [
            Vector2(0, 0),
            Vector2(10, 0),
            Vector2(10, 10),
            Vector2(0, 10),
        ]
        let light = Vector2(5, 5)
        let quads = Lighting2DShadowMath.shadowFinQuads(lightWorld: light, polygonWorldCCW: square)
        #expect(quads.isEmpty)
    }

    @Test
    func shadowFinQuads_squareOutsideLightProducesGeometry() {
        let square: [Vector2] = [
            Vector2(100, 0),
            Vector2(110, 0),
            Vector2(110, 10),
            Vector2(100, 10),
        ]
        let light = Vector2(0, 0)
        let quads = Lighting2DShadowMath.shadowFinQuads(lightWorld: light, polygonWorldCCW: square)
        #expect(!quads.isEmpty)
        #expect(quads.count % 6 == 0)
    }

    @Test
    func directionalShadowFinQuads_empty() {
        let quads = Lighting2DShadowMath.directionalShadowFinQuads(
            polygonWorldCCW: [],
            lightDirection: Vector2(0, -1)
        )
        #expect(quads.isEmpty)
    }
}
