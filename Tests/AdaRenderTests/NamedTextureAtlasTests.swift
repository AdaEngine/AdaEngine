//
//  NamedTextureAtlasTests.swift
//

import AdaRender
import Math
import XCTest

final class NamedTextureAtlasTests: XCTestCase {

    func testAtlasRegionCodableRoundTrip() throws {
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
        XCTAssertEqual(decoded.key, region.key)
        XCTAssertEqual(decoded.atlasOrigin.x, region.atlasOrigin.x)
        XCTAssertEqual(decoded.uvMin.x, region.uvMin.x)
        XCTAssertEqual(decoded.originalSize.width, region.originalSize.width)
        XCTAssertEqual(decoded.contentOriginInAtlas.y, region.contentOriginInAtlas.y)
    }
}
