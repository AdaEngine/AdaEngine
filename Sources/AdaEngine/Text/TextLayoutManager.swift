//
//  TextLayoutManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/6/23.
//

import Math

// FIXME: When text container updates each frame, than we have troubles with performance
// TODO: Add line break mode by word
// TODO: we should fit text to specific bounds in different method
// TODO: Replace invalidateLayout(in bounds) to invalidateLayout(in range: Range<String.Index>)
// TODO: Think about text container bounds property
// TODO: Add background thread for calculating all

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
        bounds: Rect = Rect(x: 0, y: 0, width: .infinity, height: .infinity),
        textAlignment: TextAlignment = .center,
        lineBreakMode: LineBreakMode = .byCharWrapping,
        lineSpacing: Float = 0
    ) {
        self.text = text
        self.bounds = bounds
        self.textAlignment = textAlignment
        self.lineBreakMode = lineBreakMode
        self.lineSpacing = lineSpacing
    }

    init() {
        self.text = ""
        self.bounds = Rect(x: 0, y: 0, width: .infinity, height: .infinity)
        self.textAlignment = .center
        self.lineBreakMode = .byCharWrapping
        self.lineSpacing = 0
    }

}

// TODO: Fix Font size

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

    private(set) var size: Size = .zero

    private(set) var textLines: [TextLine] = []

    /// All glyphs for render in text contaner bounds
    private var glyphs: [Glyph] = []
    private var glyphsToRender: GlyphRenderData?

    init() {}
    
    public func setTextContainer(_ textContainer: TextContainer) {
        if self.textContainer != textContainer {
            self.textContainer = textContainer
            self.glyphsToRender = nil
            
            self.invalidateLayout(for: textContainer.bounds)
        }
    }
    
    // swiftlint:disable function_body_length

    public func invalidateLayout(for bounds: Rect) {
        var x: Double = Double(bounds.origin.x)
        var y: Double = Double(bounds.origin.y)

        let lineHeightOffset = Double(self.textContainer.lineSpacing)
        let attributedText = self.textContainer.text

        let lines = attributedText.text.components(separatedBy: .newlines)
        self.textLines = []

        var width: Double = 0
        var height: Double = 0

        for line in lines {
            var textLine = TextLine(attributedText: attributedText, range: line.startIndex..<line.endIndex)
            var boundingBox = Rect(
                origin: bounds.origin,
                size: .zero
            )

            var maxLineHeight: Double = 0

        indecies:
            for index in line.indices {
                let attributes = attributedText.attributes(at: index)
                let char = line[index]

                let kern = Double(attributes.kern)

                let font = attributes.font
                let fontHandle = font.fontResource.handle
                let metrics = fontHandle.metrics
                let fontScale = (metrics.ascenderY - metrics.descenderY) * font.pointSize

                maxLineHeight = max(maxLineHeight, metrics.lineHeight * font.pointSize)

                for scalarIndex in char.unicodeScalars.indices {
                    let scalar = char.unicodeScalars[scalarIndex]
                    var glyph = fontHandle.getGlyph(for: scalar.value)

                    if glyph == nil {
                        glyph = fontHandle.getGlyph(for: Constants.questionMark.value)
                    }

                    guard let glyph else {
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
                        break indecies // available lines did end
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

                    textLine.glyphs.append(
                        Glyph(
                            textureAtlas: fontHandle.atlasTexture,
                            textureCoordinates: [Float(l), Float(b), Float(r), Float(t)],
                            attributes: attributes,
                            position: [Float(pl), Float(pb), Float(pr), Float(pt)],
                            size: Size(width: Float(fontScale), height: Float(fontScale))
                        )
                    )

                    var advance = glyph.advance
                    let nextScalarIndex = char.unicodeScalars.index(after: scalarIndex)

                    if char.unicodeScalars.indices.contains(nextScalarIndex) {
                        let nextScalar = char.unicodeScalars[nextScalarIndex]
                        fontHandle.getAdvance(&advance, scalar.value, nextScalar.value)
                        x += fontScale * advance + kern
                    } else {
                        x += fontScale * advance + kern
                    }
                }

                width += x
                height += y
            }

            boundingBox.size.width = Float(width + 4)
            boundingBox.size.height = Float(height + maxLineHeight)

            textLine.boundingBox = boundingBox

            self.textLines.append(textLine)
        }
    }

    func getGlyphVertexData(transform: Transform3D) -> GlyphRenderData {
        var textures: [Texture2D] = .init(repeating: .whiteTexture, count: Constants.maxTexturesPerBatch)
        var textureIndex: Int = -1
        return getGlyphVertexData(transform: transform, textures: &textures, textureSlotIndex: &textureIndex)
    }

    /// Get or create glyphs vertex data relative to transform.
    func getGlyphVertexData(transform: Transform3D, textures: inout [Texture2D], textureSlotIndex: inout Int) -> GlyphRenderData {
        if let glyphsToRender = glyphsToRender, glyphsToRender.transform == transform {
            return glyphsToRender
        }
        
        var verticies: [GlyphVertexData] = []
        var indeciesCount: Int = 0
        
        var textureIndex: Int = -1

        for textLine in textLines {
            for glyph in textLine.glyphs {
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

    /// Calculates and returns the size.
    func boundingSize(width: Float, height: Float) -> Size {
        if self.textLines.isEmpty {
            return .zero
        }

        let result = self.textLines.reduce(Size.zero) { result, line in
            return Size(
                width: max(width, result.width + line.boundingBox.width),
                height: result.height + line.boundingBox.height
            )
        }

        return result
    }

    // swiftlint:enable function_body_length
}

struct Glyph {
    let textureAtlas: Texture2D

    /// Coordinates of texturue [x: l, y: b, z: r, w: t]
    let textureCoordinates: Vector4
    let attributes: TextAttributeContainer

    /// position on plane [x: pl, y: pb, z: pr, w: pt]
    let position: Vector4

    let size: Size
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

public extension String {
    
    /// Calculates and returns the size.
    func boundingSize(width: Float, height: Float, attributes: TextAttributeContainer? = nil) -> Size {
        let attributes = attributes ?? TextAttributeContainer()
        let manager = TextLayoutManager()
        manager.setTextContainer(
            TextContainer(
                text: AttributedText(self, attributes: attributes),
                bounds: Rect(origin: .zero, size: Size(width: width, height: height))
            )
        )

        return manager.boundingSize(width: width, height: height)
    }
    
    /// Returns the bounding box size the receiver occupies when drawn with the given attributes.
    func size(with attributes: TextAttributeContainer? = nil) -> Size {
        self.boundingSize(width: .infinity, height: .infinity, attributes: attributes)
    }
}

struct TextLine {

    let attributedText: Slice<AttributedText>
    let characterRange: Range<String.Index>

    /// All glyphs for render in text contaner bounds
    var glyphs: [Glyph] = []
    var boundingBox: Rect = .zero

    init(attributedText: AttributedText, range: Range<String.Index>) {
        self.attributedText = attributedText[range]
        self.characterRange = range
    }

    @MainActor
    func draw(at point: Point, context: inout GUIRenderContext) {
        for glyph in glyphs {
            context.drawGlyph(glyph, at: point)
        }
    }
}
