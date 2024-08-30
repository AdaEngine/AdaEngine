//
//  TextLayoutManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/6/23.
//

import Math

// FIXME: When text container updates each frame, than we have troubles with performance
// FIXME: Fix TextRun, that should equals AttributedString.Run
// TODO: Add line break mode by word
// TODO: Add background thread for calculating all

/// A region where text layout occurs.
public struct TextContainer: Hashable {
    
    /// The text for rendering.
    public var text: AttributedText

    // FIXME: Fix text alignment for multiline text.
    /// The alignment of text in the box.
    /// - Warning: Under development.
    public var textAlignment: TextAlignment
    
    // FIXME: Break mode doesn't work currently
    /// The behavior of the last line inside the text container.
    /// - Warning: Under development.
    public var lineBreakMode: LineBreakMode
    
    /// The spacing between lines.
    public var lineSpacing: Float

    /// The maximum number of lines for rendering text.
    public var numberOfLines: Int?

    public init(
        text: AttributedText,
        textAlignment: TextAlignment = .center,
        lineBreakMode: LineBreakMode = .byCharWrapping,
        lineSpacing: Float = 0
    ) {
        self.text = text
        self.textAlignment = textAlignment
        self.lineBreakMode = lineBreakMode
        self.lineSpacing = lineSpacing
    }

    init() {
        self.text = ""
        self.textAlignment = .center
        self.lineBreakMode = .byCharWrapping
        self.lineSpacing = 0
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
        textAlignment: .center,
        lineBreakMode: .byCharWrapping,
        lineSpacing: 0
    )

    private(set) var size: Size = .zero
    private(set) var textLines: [TextLine] = []

    /// All glyphs for render in text contaner bounds
    private var glyphs: [Glyph] = []
    private var glyphsToRender: GlyphRenderData?

    private var availableSize: Size = Size(width: .infinity, height: .infinity)

    init() {}

    /// Set new text container to text layout.
    /// - Note: This method doesn't call ``invalidateLayout()`` method.
    public func setTextContainer(_ textContainer: TextContainer) {
        if self.textContainer != textContainer {
            self.textContainer = textContainer
        }
    }

    /// Set new constraints for size rendering.
    public func fitToSize(_ size: Size) {
        self.availableSize = size
        self.glyphsToRender = nil
        self.invalidateLayout()
    }

    // swiftlint:disable function_body_length
    
    /// Invalidate text layout, update text lines and glyphs.
    public func invalidateLayout() {
        var x: Double = 0
        var y: Double = 0

        self.glyphsToRender = nil

        let lineHeightOffset = Double(self.textContainer.lineSpacing)
        let attributedText = self.textContainer.text

        let lines = attributedText.text.components(separatedBy: .newlines)
        self.textLines = []

        let numberOfLines = self.textContainer.numberOfLines ?? lines.count

        if numberOfLines < 0 {
            print("Line limit can't be less than zero.")
            return
        }

        for line in lines[..<min(numberOfLines, lines.count)] {
            var textLine = TextLine(attributedText: attributedText, range: line.startIndex..<line.endIndex)
            var textRun = TextRun()
            var boundingBox = Rect(
                origin: Point(x: Float(x), y: Float(y)),
                size: .zero
            )

            x = 0
            y = 0

            var width: Double = 0
            var height: Double = 0

            var ascent: Double = 0
            var descent: Double = 0

            var maxLineHeight: Double = 0

        indecies:
            for index in line.indices {
                let attributes = attributedText.attributes(at: index)
                let char = line[index]

                let kern = Double(attributes.kern)

                let font = attributes.font
                let fontHandle = font.fontResource.handle
                let metrics = fontHandle.metrics
                let fontScale: Double = 1.5
                let fontSize = font.fontResource.getFontScale(for: font.pointSize)
                maxLineHeight = max(fontSize, metrics.lineHeight + font.pointSize)
                ascent = max(metrics.ascenderY, ascent)
                descent = max(metrics.descenderY, descent)

                // I'm not really think that we should for each loop here.
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

                    if Float((pr * fontScale) + x) > availableSize.width {
                        // Move to the next line
                        x = 0
                        y -= fontScale * metrics.lineHeight + lineHeightOffset + fontSize
                    }

                    if abs(Float((pt * fontScale) + y)) > availableSize.height {
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

                    textRun.glyphs.append(
                        Glyph(
                            textureAtlas: fontHandle.atlasTexture,
                            textureCoordinates: [Float(l), Float(b), Float(r), Float(t)],
                            attributes: attributes,
                            position: [Float(pl), Float(pb), Float(pr), Float(pt)],
                            origin: Point(x: -Float(fontSize) / 2, y: Float(fontSize) / 2),
                            size: Size(width: Float(fontSize), height: Float(fontSize))
                        )
                    )

                    var advance = glyph.advance
                    let nextIndex = line.index(after: index)

                    if line.indices.contains(nextIndex) {
                        if let nextScalar = line[nextIndex].unicodeScalars.first {
                            fontHandle.getAdvance(&advance, scalar.value, nextScalar.value)
                            x += fontScale * advance + kern
                        }
                    } else {
                        x += fontScale * advance + kern
                    }

                    width += fontSize
                    height += y
                }
            }

            textLine.runs.append(textRun)

            x = 0
            y = maxLineHeight.rounded(.up)

            boundingBox.size.width = Float(width).rounded(.up)
            boundingBox.size.height = Float(height + maxLineHeight).rounded(.up)

            textLine.typographicBounds.ascent = ascent
            textLine.typographicBounds.descent = descent
            textLine.typographicBounds.rect = boundingBox

            self.textLines.append(textLine)
        }
    }
    
    /// Get or create glyphs vertex data relative to transform.
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
            for run in textLine {
                for glyph in run {
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
    func boundingSize() -> Size {
        if self.textLines.isEmpty {
            return .zero
        }

        let result = self.textLines.reduce(Size.zero) { result, line in
            return Size(
                width: result.width + line.typographicBounds.rect.width,
                height: result.height + line.typographicBounds.rect.height
            )
        }

        return result
    }

    // swiftlint:enable function_body_length
}

public struct Glyph: Equatable {
    let textureAtlas: Texture2D

    /// Coordinates of texturue [x: l, y: b, z: r, w: t]
    let textureCoordinates: Vector4
    let attributes: TextAttributeContainer

    /// Position on plane [x: pl, y: pb, z: pr, w: pt]
    let position: Vector4

    let origin: Point

    /// Size of glyph.
    let size: Size

    public static func == (lhs: Glyph, rhs: Glyph) -> Bool {
        lhs.size == rhs.size && lhs.position == rhs.position && lhs.textureCoordinates == rhs.textureCoordinates
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

public extension String {
    
    /// Calculates and returns the size.
    func boundingSize(width: Float, height: Float, attributes: TextAttributeContainer? = nil) -> Size {
        let attributes = attributes ?? TextAttributeContainer()
        let manager = TextLayoutManager()
        manager.setTextContainer(
            TextContainer(
                text: AttributedText(self, attributes: attributes)
            )
        )
        manager.fitToSize(Size(width: width, height: height))

        return manager.boundingSize()
    }
    
    /// Returns the bounding box size the receiver occupies when drawn with the given attributes.
    func size(with attributes: TextAttributeContainer? = nil) -> Size {
        self.boundingSize(width: .infinity, height: .infinity, attributes: attributes)
    }
}

/// A single line in a text layout: a collection of runs of placed glyphs.
public struct TextLine: Equatable {

    let attributedText: Slice<AttributedText>
    let characterRange: Range<String.Index>

    /// All glyphs for render in text contaner bounds
    var runs: [TextRun] = []
    public internal(set) var typographicBounds: TypographicBounds = TypographicBounds()

    init(attributedText: AttributedText, range: Range<String.Index>) {
        self.attributedText = attributedText[range]
        self.characterRange = range
    }

    public static func == (lhs: TextLine, rhs: TextLine) -> Bool {
        lhs.runs == rhs.runs && lhs.typographicBounds == rhs.typographicBounds && lhs.characterRange == rhs.characterRange
    }
}

/// The typographic bounds of an element in a text layout.
public struct TypographicBounds: Equatable {
    /// The ascent of the element.
    public internal(set) var ascent: Double = .zero

    /// The descent of the element.
    public internal(set) var descent: Double = .zero

    /// The position of the left edge of the element’s baseline, relative to the text view.
    public var origin: Point {
        rect.origin
    }

    /// Returns a rectangle encapsulating the bounds.
    public internal(set) var rect: Rect

    init() {
        self.rect = .zero
    }
}

extension TextLine: Collection, Sequence {

    public typealias Element = TextRun
    public typealias Index = Int

    public var startIndex: Int {
        self.runs.startIndex
    }

    public var endIndex: Int {
        self.runs.endIndex
    }

    public subscript(position: Int) -> TextRun {
        _read {
            yield self.runs[position]
        }
    }

    public func index(after i: Int) -> Int {
        self.runs.index(after: i)
    }
}

/// A run of placed glyphs in a text layout.
public struct TextRun: Equatable {
    /// All glyphs for render in text contaner bounds
    var glyphs: [Glyph] = []

    public internal(set) var typographicBounds: TypographicBounds = TypographicBounds()
}

extension TextRun: Collection, Sequence {
    public typealias Element = Glyph
    public typealias Index = Int

    public var startIndex: Int {
        self.glyphs.startIndex
    }
    
    public var endIndex: Int {
        self.glyphs.endIndex
    }

    public subscript(position: Int) -> Glyph {
        _read {
            yield self.glyphs[position]
        }
    }

    public func index(after i: Int) -> Int {
        self.glyphs.index(after: i)
    }
}
