//
//  TextLayoutManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/6/23.
//

import AdaRender
import AdaUtils
import Math
import AtlasFontGenerator
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// FIXME: Fix TextRun, that should equals AttributedString.Run
// TODO: Add line break mode by word

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

    public init() {
        self.text = ""
        self.textAlignment = .center
        self.lineBreakMode = .byCharWrapping
        self.lineSpacing = 0
    }

}

/// An object that coordinates the layout and display of text characters.
/// TextLayoutManager maps unicods characters codes to glyphs.
public final class TextLayoutManager: @unchecked Sendable {
    
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

    public private(set) var size: Size = .zero
    public private(set) var textLines: [TextLine] = []
    
    /// The text alignment of the text container.
    public var textAlignment: TextAlignment {
        textContainer.textAlignment
    }

    /// All glyphs for render in text contaner bounds
    private var glyphs: [Glyph] = []
    private var glyphsToRender: GlyphRenderData?

    private var availableSize: Size = Size(width: .infinity, height: .infinity)

    public init() {}

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

    // FIXME: TextLayoutManager calculate the wrong position
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
            assertionFailure("Line limit can't be less than zero.")
            return
        }

        var currentTextIndex = attributedText.text.startIndex

        for lineString in lines[..<min(numberOfLines, lines.count)] {
            // Find the range of this line in the original attributed text
            let lineStartIndex = currentTextIndex
            let lineEndIndex = attributedText.text.index(lineStartIndex, offsetBy: lineString.count, limitedBy: attributedText.text.endIndex) ?? attributedText.text.endIndex
            
            // Handle newline character if not at the end
            if lineEndIndex < attributedText.text.endIndex && attributedText.text[lineEndIndex] == "\n" {
                currentTextIndex = attributedText.text.index(after: lineEndIndex)
            } else {
                currentTextIndex = lineEndIndex
            }
            
            let lineRange = lineStartIndex..<lineEndIndex
            var textLine = TextLine(attributedText: attributedText, range: lineRange)
            var textRun = TextRun()
            
            // Reset x for each new line, but keep accumulating y
            x = 0
            
            // Calculate the starting y position for this line's bounding box
            let lineStartY = y

            var maxWidth: Double = 0
            var maxAscent: Double = 0
            var maxDescent: Double = 0
            var maxLineHeight: Double = 0

            var index = lineStartIndex
            while index < lineEndIndex {
                let attributes = attributedText.attributes(at: index)
                let char = attributedText.text[index]

                let kern = Double(attributes.kern)

                let font = attributes.font
                let fontHandle = font.fontResource.handle
                let metrics = fontHandle.metrics
                // Scale glyph positions based on font point size relative to em size
                let fontScale: Double = font.pointSize / metrics.emSize
                let fontSize = font.fontResource.getFontScale(for: font.pointSize)
                let lineHeight = fontScale * metrics.lineHeight
                maxLineHeight = max(maxLineHeight, lineHeight + lineHeightOffset)
                maxAscent = max(maxAscent, metrics.ascenderY * fontScale)
                maxDescent = max(maxDescent, abs(metrics.descenderY * fontScale))

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
                        y -= maxLineHeight
                    }

                    if abs(Float((pt * fontScale) + y)) > availableSize.height {
                        // available lines did end
                        index = lineEndIndex
                        break
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

                    // Track the maximum width (rightmost edge of glyphs) before advance
                    maxWidth = max(maxWidth, pr)

                    var advance = glyph.advance
                    let nextIndex = attributedText.text.index(after: index)

                    if nextIndex < lineEndIndex {
                        if let nextChar = nextIndex < attributedText.text.endIndex ? attributedText.text[nextIndex] : nil,
                           let nextScalar = nextChar.unicodeScalars.first {
                            fontHandle.getAdvance(&advance, scalar.value, nextScalar.value)
                            x += fontScale * advance + kern
                        }
                    } else {
                        x += fontScale * advance + kern
                    }
                }
                
                if index < lineEndIndex {
                    index = attributedText.text.index(after: index)
                } else {
                    break
                }
            }

            textLine.runs.append(textRun)

            // Calculate bounding box for this line
            let boundingBox = Rect(
                origin: Point(x: 0, y: Float(lineStartY)),
                size: Size(width: Float(maxWidth), height: Float(maxLineHeight))
            )
            
            textLine.typographicBounds.ascent = maxAscent
            textLine.typographicBounds.descent = maxDescent
            textLine.typographicBounds.rect = boundingBox
            self.textLines.append(textLine)
            
            // Move y down for the next line
            y -= maxLineHeight
        }
    }
    
    /// Get or create glyphs vertex data relative to transform.
    public func getGlyphVertexData(transform: Transform3D) -> GlyphRenderData {
        var textures: [Texture2D] = .init(repeating: .whiteTexture, count: Constants.maxTexturesPerBatch)
        var textureIndex: Int = -1
        return getGlyphVertexData(transform: transform, textures: &textures, textureSlotIndex: &textureIndex)
    }

    /// Get or create glyphs vertex data relative to transform.
    public func getGlyphVertexData(
        transform: Transform3D,
        textures: inout [Texture2D],
        textureSlotIndex: inout Int,
        ignoreCache: Bool = false
    ) -> GlyphRenderData {
        if let glyphsToRender = glyphsToRender, glyphsToRender.transform == transform, !ignoreCache {
            return glyphsToRender
        }
        
        // Calculate text bounding size for centering
        let textSize = self.boundingSize()
        
        // Calculate offset for text alignment (centering by default)
        var offsetX: Float = 0
        var offsetY: Float = 0
        
        switch self.textContainer.textAlignment {
        case .center:
            // Center horizontally and vertically
            offsetX = -textSize.width / 2
            // Find the topmost y position (most positive) to center vertically
            if let firstLine = textLines.first, !textLines.isEmpty {
                let topY = firstLine.typographicBounds.rect.origin.y
                let bottomY = topY - textSize.height
                offsetY = -(topY + bottomY) / 2
            }
        case .leading:
            // Align to left, center vertically
            offsetX = 0
            if let firstLine = textLines.first, !textLines.isEmpty {
                let topY = firstLine.typographicBounds.rect.origin.y
                let bottomY = topY - textSize.height
                offsetY = -(topY + bottomY) / 2
            }
        case .trailing:
            // Align to right, center vertically
            offsetX = -textSize.width
            if let firstLine = textLines.first, !textLines.isEmpty {
                let topY = firstLine.typographicBounds.rect.origin.y
                let bottomY = topY - textSize.height
                offsetY = -(topY + bottomY) / 2
            }
        }
        
        var verticies: [GlyphVertexData] = []
        var indeciesCount: Int = 0
        
        var textureIndex: Int = -1

        for textLine in textLines {
            // Calculate line-specific offset for horizontal alignment
            var lineOffsetX = offsetX
            if self.textContainer.textAlignment == .center || self.textContainer.textAlignment == .trailing {
                let lineWidth = textLine.typographicBounds.rect.width
                if self.textContainer.textAlignment == .center {
                    lineOffsetX = offsetX + (textSize.width - lineWidth) / 2
                } else {
                    lineOffsetX = offsetX + (textSize.width - lineWidth)
                }
            }
            
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

                    // Apply centering offset before transform
                    let adjustedX1 = glyph.position.x + lineOffsetX
                    let adjustedY1 = glyph.position.y - offsetY
                    let adjustedX2 = glyph.position.z + lineOffsetX
                    let adjustedY2 = glyph.position.w - offsetY

                    verticies.append(
                        GlyphVertexData(
                            position: transform * Vector4(x: adjustedX2, y: adjustedY1, z: 0, w: 1),
                            foregroundColor: foregroundColor,
                            outlineColor: outlineColor,
                            textureCoordinate: [ textureCoordinate.z, textureCoordinate.y ],
                            textureIndex: textureIndex
                        )
                    )

                    verticies.append(
                        GlyphVertexData(
                            position: transform * Vector4(x: adjustedX2, y: adjustedY2, z: 0, w: 1),
                            foregroundColor: foregroundColor,
                            outlineColor: outlineColor,
                            textureCoordinate: [ textureCoordinate.z, textureCoordinate.w ],
                            textureIndex: textureIndex
                        )
                    )

                    verticies.append(
                        GlyphVertexData(
                            position: transform * Vector4(x: adjustedX1, y: adjustedY2, z: 0, w: 1),
                            foregroundColor: foregroundColor,
                            outlineColor: outlineColor,
                            textureCoordinate: [ textureCoordinate.x, textureCoordinate.w ],
                            textureIndex: textureIndex
                        )
                    )

                    verticies.append(
                        GlyphVertexData(
                            position: transform * Vector4(x: adjustedX1, y: adjustedY1, z: 0, w: 1),
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
    public func boundingSize() -> Size {
        if self.textLines.isEmpty {
            return .zero
        }

        var maxWidth: Float = 0
        var totalHeight: Float = 0

        for line in self.textLines {
            maxWidth = max(maxWidth, line.typographicBounds.rect.width)
            totalHeight += line.typographicBounds.rect.height
        }

        return Size(width: maxWidth, height: totalHeight)
    }

    // swiftlint:enable function_body_length
}

public struct Glyph: Sendable, Equatable {
    public let textureAtlas: Texture2D

    /// Coordinates of texturue [x: l, y: b, z: r, w: t]
    public let textureCoordinates: Vector4
    public let attributes: TextAttributeContainer

    /// Position on plane [x: pl, y: pb, z: pr, w: pt]
    public let position: Vector4

    public let origin: Point

    /// Size of glyph.
    public let size: Size

    public static func == (lhs: Glyph, rhs: Glyph) -> Bool {
        lhs.size == rhs.size && lhs.position == rhs.position && lhs.textureCoordinates == rhs.textureCoordinates
    }
}

public struct GlyphRenderData {
    public var transform: Transform3D
    public var verticies: [GlyphVertexData] = []
    public var indeciesCount: Int = 0
    public var textures: [Texture2D?] = []
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
