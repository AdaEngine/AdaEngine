//
//  TextLayoutManager.swift
//  
//
//  Created by v.prusakov on 3/6/23.
//

final class TextLayoutManager {
    
    typealias GlyphIndex = UInt32
    
    var attributedText: AttributedText = ""
    
    init() {}
    
    private var glyphsToRender: GlyphRenderData = GlyphRenderData()
    
    func replaceText(_ text: AttributedText) {
        self.attributedText = text
        self.glyphsToRender = GlyphRenderData()
    }
    
//    func getGlyph(at index: GlyphIndex, font: Font) -> Glyph {
//        let fontHandle = font.handle
//        var fontGlyph = fontHandle.fontData.fontGeometry.__getGlyphUnsafe(index)
//
//        if fontGlyph == nil {
//            fontGlyph = fontHandle.fontData.fontGeometry.__getGlyphUnsafe(Character("?").unicodeScalars.first!.value)
//        }
//
//        guard let fontGlyph else {
//            fatalError("Can't get a glyph")
//        }
//
//        var x: Int32 = 0, y: Int32 = 0, w: Int32 = 0, h: Int32 = 0
//        fontGlyph.getBoxRect(&x, &y, &w, &h)
//
//        let bounds = Rect(x: Float(x), y: Float(y), width: Float(w), height: Float(h))
//
//        var l: Double = 0, b: Double = 0, r: Double = 0, t: Double = 0
//        fontGlyph.getQuadAtlasBounds(&l, &b, &r, &t)
//
//        return Glyph(texture: fontHandle.atlasTexture, bounds: bounds)
//    }
    
//    func calculateGlyphs(for bounds: Rect) -> [GlyphIndex] {
//        let scalars = self.attributedText.text.unicodeScalars
//
//
//    }
    
    // FIXME: SOOOOO SLOOOW!!!
    
    // swiftlint:disable:next function_body_length
    func getGlyphVertexData(
        in bounds: Rect,
        textAlignment: TextAlignment,
        transform: Transform3D
    ) -> GlyphRenderData {
        var x: Double = 0
        var y: Double = 0
        
        var currentLine: Int = -1
        var currentLineWidth: Double = 0
        var lineHeightOffset: Double = 0
        
        var verticies: [GlyphVertexData] = []
        var indeciesCount: Int = 0
        
        let questionMark = Character("?").unicodeScalars.first!
        
        var textureIndex: Int = -1
        var textures: [Texture2D?] = .init(repeating: nil, count: 32)
        
        let kerningOffset: Double = 0
        
        for index in self.attributedText.text.indices {
            let attributes = self.attributedText.attributes(at: index)
            let char = self.attributedText.text[index]
            
            let foregroundColor = attributes.values.foregroundColor
            let outlineColor = attributes.values.outlineColor
            let kern = Double(attributes.values.kern)
            
            let fontHandle = attributes.values.font.handle
            let fontGeometry = fontHandle.fontData.pointee.fontGeometry
            let metrics = fontGeometry.__getMetricsUnsafe().pointee
            let fontScale = 1 / (metrics.ascenderY - metrics.descenderY)
            
            if let index = textures.firstIndex(where: { fontHandle.atlasTexture === $0 }) {
                textureIndex = index
            } else {
                textureIndex += 1
                textures[textureIndex] = fontHandle.atlasTexture
            }
            
            for scalarIndex in char.unicodeScalars.indices {
                let scalar = char.unicodeScalars[scalarIndex]
                var glyph = fontGeometry.__getGlyphUnsafe(scalar.value)
                
                if glyph == nil {
                    glyph = fontGeometry.__getGlyphUnsafe(questionMark.value)
                }
                
                guard let glyph else {
                    continue
                }
                
                if char.isNewline {
                    x = 0
                    y -= fontScale * metrics.lineHeight + lineHeightOffset
                    continue
                }
                
                var l: Double = 0, b: Double = 0, r: Double = 0, t: Double = 0
                glyph.getQuadAtlasBounds(&l, &b, &r, &t)
                
                var pl: Double = 0, pb: Double = 0, pr: Double = 0, pt: Double = 0
                glyph.getQuadPlaneBounds(&pl, &pb, &pr, &pt)
                
                pl = (pl * fontScale) + x
                pb = (pb * fontScale) + y
                pr = (pr * fontScale) + x
                pt = (pt * fontScale) + y
                
                let texelWidth = 1 / Double(fontHandle.atlasTexture.width)
                let texelHeight = 1 / Double(fontHandle.atlasTexture.height)
                l *= texelWidth
                b *= texelHeight
                r *= texelWidth
                t *= texelHeight
                
                let textureSize = Vector2(
                    x: Float(fontHandle.atlasTexture.width),
                    y: Float(fontHandle.atlasTexture.height)
                )
                
                verticies.append(
                    GlyphVertexData(
                        position: transform * Vector4(x: Float(pr), y: Float(pb), z: 0, w: 1),
                        foregroundColor: foregroundColor,
                        outlineColor: outlineColor,
                        textureCoordinate: [ Float(r), Float(b) ],
                        textureSize: textureSize,
                        textureIndex: textureIndex
                    )
                )
                
                verticies.append(
                    GlyphVertexData(
                        position: transform * Vector4(x: Float(pr), y: Float(pt), z: 0, w: 1),
                        foregroundColor: foregroundColor,
                        outlineColor: outlineColor,
                        textureCoordinate: [ Float(r), Float(t) ],
                        textureSize: textureSize,
                        textureIndex: textureIndex
                    )
                )
                
                verticies.append(
                    GlyphVertexData(
                        position: transform * Vector4(x: Float(pl), y: Float(pt), z: 0, w: 1),
                        foregroundColor: foregroundColor,
                        outlineColor: outlineColor,
                        textureCoordinate: [ Float(l), Float(t) ],
                        textureSize: textureSize,
                        textureIndex: textureIndex
                    )
                )
                
                verticies.append(
                    GlyphVertexData(
                        position: transform * Vector4(x: Float(pl), y: Float(pb), z: 0, w: 1),
                        foregroundColor: foregroundColor,
                        outlineColor: outlineColor,
                        textureCoordinate: [ Float(l), Float(b) ],
                        textureSize: textureSize,
                        textureIndex: textureIndex
                    )
                )
                
                indeciesCount += 6
                
                var advance = glyph.getAdvance()
                let nextScalarIndex = char.unicodeScalars.index(after: scalarIndex)
                
                if char.unicodeScalars.indices.contains(nextScalarIndex) {
                    let nextScalar = char.unicodeScalars[nextScalarIndex]
                    fontGeometry.getAdvance(&advance, scalar.value, nextScalar.value)
                    x += fontScale * advance + kern
                } else {
                    x += fontScale * advance + kern
                }
            }
        }
        
        return GlyphRenderData(verticies: verticies, indeciesCount: indeciesCount, textures: textures)
    }
    
}

struct GlyphRenderData {
    var verticies: [GlyphVertexData] = []
    var indeciesCount: Int = 0
    var textures: [Texture2D?] = []
}

struct GlyphVertexData {
    let position: Vector4
    let foregroundColor: Color
    let outlineColor: Color
    let textureCoordinate: Vector2
    let textureSize: Vector2
    let textureIndex: Int
}
