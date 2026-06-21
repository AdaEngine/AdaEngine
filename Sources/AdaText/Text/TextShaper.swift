import AdaTextShaper
import Foundation

struct ShapedGlyph: Equatable {
    let glyphIndex: Int32
    let cluster: Int
    let xAdvance: Double
    let yAdvance: Double
    let xOffset: Double
    let yOffset: Double
}

enum TextShaper {
    static func shape(_ text: String, font: FontResource) -> [ShapedGlyph] {
        guard !text.isEmpty, let fontPath = font.handle.fontPath else {
            return []
        }

        let utf8Count = text.utf8.count
        guard utf8Count > 0 else {
            return []
        }

        let variationAxes = font.handle.variationAxes.map { axis in
            ada_font_variation_axis_t(tag: axis.tag, value: axis.value)
        }
        let shapedText = fontPath.path.withCString { fontPathPointer in
            text.withCString { textPointer in
                unsafe variationAxes.withUnsafeBufferPointer { axes in
                    unsafe ada_text_shape_utf8_with_variations(
                        fontPathPointer,
                        textPointer,
                        Int32(utf8Count),
                        axes.baseAddress,
                        Int32(axes.count)
                    )
                }
            }
        }

        guard let shapedText else {
            return []
        }

        defer {
            unsafe ada_shaped_text_destroy(shapedText)
        }

        let shapedTextValue = unsafe shapedText.pointee
        guard shapedTextValue.glyphCount > 0, let glyphs = shapedTextValue.glyphs else {
            return []
        }

        return (0..<Int(shapedTextValue.glyphCount)).map { index in
            let glyph = unsafe glyphs[index]
            return ShapedGlyph(
                glyphIndex: Int32(glyph.glyphIndex),
                cluster: Int(glyph.cluster),
                xAdvance: glyph.xAdvance,
                yAdvance: glyph.yAdvance,
                xOffset: glyph.xOffset,
                yOffset: glyph.yOffset
            )
        }
    }
}
