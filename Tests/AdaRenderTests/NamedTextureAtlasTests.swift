//
//  NamedTextureAtlasTests.swift
//

import AdaRender
import Foundation
import Math
import Testing

@Suite("NamedTextureAtlas")
struct NamedTextureAtlasTests {

    @Test
    func atlasRegionCodableRoundTrip() throws {
        let region = AtlasRegion(
            key: "home",
            atlasOrigin: PointInt(x: 2, y: 3),
            atlasSize: SizeInt(width: 16, height: 16),
            uvMin: Vector2(0.1, 0.2),
            uvMax: Vector2(0.3, 0.4),
            originalSize: SizeInt(width: 12, height: 12),
            contentOriginInAtlas: PointInt(x: 4, y: 5)
        )
        let data = try JSONEncoder().encode(region)
        let decoded = try JSONDecoder().decode(AtlasRegion.self, from: data)
        #expect(decoded.key == region.key)
        #expect(decoded.atlasOrigin.x == region.atlasOrigin.x)
        #expect(decoded.uvMin.x == region.uvMin.x)
        #expect(decoded.originalSize.width == region.originalSize.width)
        #expect(decoded.contentOriginInAtlas.y == region.contentOriginInAtlas.y)
    }
}
