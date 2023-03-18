//
//  TextLayoutManager.swift
//  
//
//  Created by v.prusakov on 3/6/23.
//

// FIXME: When text container updates each frame, than we have troubles with performance
// TODO: Add line break mode by word

/// A region where text layout occurs.
public struct TextContainer: Hashable {
    
    /// The text for rendering.
    public var text: AttributedText
    
    /// The size of the text container’s bounding rectangle.
    public var bounds: Rect
    
    /// The alignment of text in the box.
    public var textAlignment: TextAlignment
    
    /// The behavior of the last line inside the text container.
    public var lineBreakMode: LineBreakMode
    
    /// The spacing between lines.
    public var lineSpacing: Float
    
    public init(
        text: AttributedText,
        bounds: Rect,
        textAlignment: TextAlignment,
        lineBreakMode: LineBreakMode,
        lineSpacing: Float
    ) {
        self.text = text
        self.bounds = bounds
        self.textAlignment = textAlignment
        self.lineBreakMode = lineBreakMode
        self.lineSpacing = lineSpacing
    }
    
}

/// An object that coordinates the layout and display of text characters.
/// TextLayoutManager maps unicods characters codes to glyphs.
public final class TextLayoutManager {
    
    enum Constants {
        static let questionMark = Character("?").unicodeScalars.first!
        static let dots = Character("…").unicodeScalars.first!
        static let maxTexturesPerBatch = 16
    }
    
    private var textContainer: TextContainer = TextContainer(
        text: "",
        bounds: .init(x: 0, y: 0, width: .infinity, height: .infinity),
        textAlignment: .center,
        lineBreakMode: .byCharWrapping,
        lineSpacing: 0
    )
    
    /// All glyphs for render in text contaner bounds
    private var glyphs: [Glyph] = []
    
    init() {}
    
    private var glyphsToRender: GlyphRenderData?
    
    public func setTextContainer(_ textContainer: TextContainer) {
        if self.textContainer != textContainer {
            self.textContainer = textContainer
            self.glyphsToRender = nil
            
//            self.invalidateDisplay(for: textContainer.bounds)
        }
    }
    
    // swiftlint:disable function_body_length
    
    /// Fit text to bounds and update rendered glyphs.
    public func invalidateDisplay(for bounds: Rect) {
        var x: Double = Double(bounds.origin.x)
        var y: Double = Double(bounds.origin.y)
        
        self.glyphs.removeAll(keepingCapacity: true)
        
        let lineHeightOffset = Double(self.textContainer.lineSpacing)
        
        var textureIndex: Int = -1
        var textures: [Texture2D?] = .init(repeating: nil, count: Constants.maxTexturesPerBatch)
        let attributedText = self.textContainer.text
        
        for index in attributedText.text.indices {
            let attributes = attributedText.attributes(at: index)
            let char = attributedText.text[index]
            
            let kern = Double(attributes.kern)
            
            let fontHandle = attributes.font.handle
            let fontGeometry = fontHandle.fontData.pointee.fontGeometry
            let metrics = fontGeometry.getMetrics().pointee
            let fontScale = 1 / (metrics.ascenderY - metrics.descenderY)
            
            if let index = textures.firstIndex(where: { fontHandle.atlasTexture === $0 }) {
                textureIndex = index
            } else {
                textureIndex += 1
                textures[textureIndex] = fontHandle.atlasTexture
            }
            
            for scalarIndex in char.unicodeScalars.indices {
                let scalar = char.unicodeScalars[scalarIndex]
                var glyph = fontGeometry.getGlyph(scalar.value)
                
                if glyph == nil {
                    glyph = fontGeometry.getGlyph(Constants.questionMark.value)
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
                
                if Float((pr * fontScale) + x) > bounds.size.width {
                    x = 0
                    y -= fontScale * metrics.lineHeight + lineHeightOffset
                }
                
                if abs(Float((pt * fontScale) + y)) > bounds.size.height {
                    // TODO: Add
                    return // available lines did end
                }
                
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
                
                self.glyphs.append(Glyph(
                    textureAtlas: fontHandle.atlasTexture,
                    textureCoordinates: [Float(l), Float(b), Float(r), Float(t)],
                    attributes: attributes,
                    position: [Float(pl), Float(pb), Float(pr), Float(pt)])
                )
                
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
    }
    
    /// Get or create glyphs vertex data relative to transform.
    func getGlyphVertexData(transform: Transform3D) -> GlyphRenderData {
        if let glyphsToRender = glyphsToRender, glyphsToRender.transform == transform {
            return glyphsToRender
        }
        
        var verticies: [GlyphVertexData] = []
        var indeciesCount: Int = 0
        
        var textureIndex: Int = -1
        var textures: [Texture2D?] = .init(repeating: nil, count: Constants.maxTexturesPerBatch)
        
        for glyph in self.glyphs {
            let texture = glyph.textureAtlas
            let foregroundColor = glyph.attributes.foregroundColor
            let outlineColor = glyph.attributes.outlineColor
            let textureCoordinate = glyph.textureCoordinates
            
            if let index = textures.firstIndex(where: { $0 === texture }) {
                textureIndex = index
            } else {
                textureIndex += 1
                textures[textureIndex] = texture
            }
            
            verticies.append(
                GlyphVertexData(
                    position: transform * Vector4(x: glyph.position.z, y: glyph.position.y, z: 0, w: 1),
                    foregroundColor: foregroundColor,
                    outlineColor: outlineColor,
                    textureCoordinate: [ textureCoordinate.z, textureCoordinate.y ],
                    textureIndex: textureIndex
                )
            )
            
            verticies.append(
                GlyphVertexData(
                    position: transform * Vector4(x: glyph.position.z, y: glyph.position.w, z: 0, w: 1),
                    foregroundColor: foregroundColor,
                    outlineColor: outlineColor,
                    textureCoordinate: [ textureCoordinate.z, textureCoordinate.w ],
                    textureIndex: textureIndex
                )
            )
            
            verticies.append(
                GlyphVertexData(
                    position: transform * Vector4(x: glyph.position.x, y: glyph.position.w, z: 0, w: 1),
                    foregroundColor: foregroundColor,
                    outlineColor: outlineColor,
                    textureCoordinate: [ textureCoordinate.x, textureCoordinate.w ],
                    textureIndex: textureIndex
                )
            )
            
            verticies.append(
                GlyphVertexData(
                    position: transform * Vector4(x: glyph.position.x, y: glyph.position.y, z: 0, w: 1),
                    foregroundColor: foregroundColor,
                    outlineColor: outlineColor,
                    textureCoordinate: [ textureCoordinate.x, textureCoordinate.y ],
                    textureIndex: textureIndex
                )
            )
            
            indeciesCount += 6
        }
        
        let render = GlyphRenderData(
            transform: transform,
            verticies: verticies,
            indeciesCount: indeciesCount,
            textures: textures
        )
        
        self.glyphsToRender = render
        
        return render
    }
    
    // swiftlint:enable function_body_length
}

extension TextLayoutManager {
    struct Glyph {
        let textureAtlas: Texture2D
        
        /// Coordinates of texturue [x: l, y: b, z: r, w: t]
        let textureCoordinates: Vector4
        let attributes: TextAttributeContainer
        
        /// position on plane [x: pl, y: pb, z: pr, w: pt]
        let position: Vector4
    }
}

struct GlyphRenderData {
    var transform: Transform3D
    var verticies: [GlyphVertexData] = []
    var indeciesCount: Int = 0
    var textures: [Texture2D?] = []
}

struct GlyphVertexData {
    let position: Vector4
    let foregroundColor: Color
    let outlineColor: Color
    let textureCoordinate: Vector2
    let textureIndex: Int
}
