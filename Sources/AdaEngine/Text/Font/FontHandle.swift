//
//  FontHandle.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/19/23.
//

#if ENABLE_FONT_GENERATOR
@_implementationOnly import AtlasFontGenerator
#endif

/// Hold information about font data and atlas.
final class FontHandle: Hashable, @unchecked Sendable {
    
    let atlasTexture: Texture2D
    let fontData: OpaquePointer!
    
    #if ENABLE_FONT_GENERATOR
    let metrics: FontMetrics
    #endif
    let fontName: String
    let geometryScale: Double
    
    init(atlasTexture: Texture2D, fontData: OpaquePointer) {
        self.atlasTexture = atlasTexture
        self.fontData = fontData
        
        #if ENABLE_FONT_GENERATOR
        self.metrics = font_geometry_get_metrics(fontData)
        self.fontName = String(cString: font_geometry_get_name(fontData)!)
        self.geometryScale = font_geometry_get_scale(fontData)
        #else
        self.fontName = ""
        self.geometryScale = 0
        #endif
    }
    
    deinit {
        #if ENABLE_FONT_GENERATOR
        font_handle_destroy(self.fontData)
        #endif
    }
    
    func getGlyph(for scalar: UInt32) -> Glyph? {
        #if ENABLE_FONT_GENERATOR
        guard let glyph = font_handle_get_glyph_unicode(self.fontData, scalar) else {
            return nil
        }
        
        return Glyph(ref: glyph)
        #else
        return nil
        #endif
    }
    
    func getAdvance(_ advance: inout Double, _ currentUnicode: UInt32, _ nextUnicode: UInt32) {
        #if ENABLE_FONT_GENERATOR
        font_handle_get_advance(self.fontData, &advance, currentUnicode, nextUnicode)
        #endif
    }
    
    var glyphsCount: Int {
        #if ENABLE_FONT_GENERATOR
        return font_handle_get_glyphs_count(self.fontData)
        #else
        return 0
        #endif
    }
    
    // MARK: Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.fontName)
        hasher.combine(self.geometryScale)
        #if ENABLE_FONT_GENERATOR
        hasher.combine(self.metrics.underlineThickness)
        hasher.combine(self.metrics.underlineY)
        hasher.combine(self.metrics.emSize)
        hasher.combine(self.metrics.ascenderY)
        hasher.combine(self.metrics.descenderY)
        hasher.combine(self.metrics.lineHeight)
        #endif
    }
    
    static func == (lhs: FontHandle, rhs: FontHandle) -> Bool {
        return lhs.fontName == rhs.fontName
        && lhs.geometryScale == rhs.geometryScale
        #if ENABLE_FONT_GENERATOR
//        && lhs.metrics.emSize == rhs.metrics.emSize
//        && lhs.metrics.lineHeight == rhs.metrics.lineHeight
//        && lhs.metrics.ascenderY == rhs.metrics.ascenderY
//        && lhs.metrics.descenderY == rhs.metrics.descenderY
//        && lhs.metrics.underlineY == rhs.metrics.underlineY
//        && lhs.metrics.underlineThickness == rhs.metrics.underlineThickness
//        && lhs.glyphsCount == rhs.glyphsCount
        #endif
    }
}

extension FontHandle {
    
    final class Glyph {
        let ref: OpaquePointer
        
        init(ref: OpaquePointer) {
            self.ref = ref
        }
        
        deinit {
            self.ref.deallocate()
        }
        
        var advance: Double {
            #if ENABLE_FONT_GENERATOR
            return font_glyph_get_advance(self.ref)
            #else
            return 0
            #endif
        }
        
        func getQuadAtlasBounds(_ l: inout Double, _ b: inout Double, _ r: inout Double, _ t: inout Double) {
            #if ENABLE_FONT_GENERATOR
            font_glyph_get_quad_atlas_bounds(self.ref, &l, &b, &r, &t)
            #endif
        }
        
        func getQuadPlaneBounds(_ pl: inout Double, _ pb: inout Double, _ pr: inout Double, _ pt: inout Double) {
            #if ENABLE_FONT_GENERATOR
            font_glyph_get_quad_plane_bounds(self.ref, &pl, &pb, &pr, &pt)
            #endif
        }
    }
    
}

extension OpaquePointer {

    // TODO: Should we deallocate it in this place?
    func deallocate() {
        UnsafeRawPointer(self).deallocate()
    }
}
