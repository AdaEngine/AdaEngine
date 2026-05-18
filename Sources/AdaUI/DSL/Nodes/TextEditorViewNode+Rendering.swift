//
//  TextEditorViewNode+Rendering.swift
//  AdaEngine
//
//  Created by Codex on 18.05.2026.
//

import AdaRender
import AdaText
import AdaUtils
import Foundation
import Math

extension TextEditorViewNode {

    func drawSelectionIfNeeded(
        in context: inout UIGraphicsContext,
        line: LineInfo,
        lineIndex: Int,
        rowY: Float,
        lineHeight: Float,
        pointSize: Float
    ) {
        guard self.isFocused, self.hasSelection else {
            return
        }

        let range = self.selectionRange
        let lineStart = line.startOffset
        let lineEnd = line.startOffset + line.text.count
        let includesTrailingNewline = lineIndex < self.lines().count - 1
        let selectableEnd = includesTrailingNewline ? lineEnd + 1 : lineEnd
        let start = max(range.lowerBound, lineStart)
        let end = min(range.upperBound, selectableEnd)

        guard end > start else {
            return
        }

        let characterAdvance = self.characterAdvance(for: pointSize)
        let textRect = self.textRect()
        let startColumn = max(0, min(start - lineStart, line.text.count))
        let endColumn = end > lineEnd ? line.text.count + 1 : max(0, min(end - lineStart, line.text.count))
        let startX = textRect.minX + Float(startColumn) * characterAdvance - self.scrollOffset.x
        let endX = textRect.minX + Float(endColumn) * characterAdvance - self.scrollOffset.x

        context.drawRect(
            Rect(x: startX, y: rowY, width: max(characterAdvance, endX - startX), height: lineHeight),
            color: self.environment.textEditorColors.selection
        )
    }

    func drawString(_ string: String, font: Font, color: Color, in context: inout UIGraphicsContext, at point: Point) {
        guard !string.isEmpty else {
            return
        }

        let layout = TextLayoutManager()
        var attributes = TextAttributeContainer()
        attributes.font = font
        attributes.foregroundColor = color

        var container = TextContainer(text: AttributedText(string, attributes: attributes), textAlignment: .leading)
        container.numberOfLines = 1
        layout.setTextContainer(container)
        layout.fitToSize(Size(width: .infinity, height: self.lineHeight(for: Float(font.pointSize))))

        let verticalOffset = Self.verticalTextOffset(for: layout, height: self.lineHeight(for: Float(font.pointSize)))
        context.translateBy(x: point.x, y: -(point.y) + verticalOffset)
        for line in layout.textLines {
            for run in line {
                for glyph in run {
                    context.draw(glyph)
                }
            }
        }
        context.translateBy(x: -point.x, y: point.y - verticalOffset)
    }

    func drawBorder(in context: inout UIGraphicsContext, rect: Rect, color: Color) {
        let topLeft = Point(rect.minX, -rect.minY)
        let topRight = Point(rect.maxX, -rect.minY)
        let bottomLeft = Point(rect.minX, -rect.maxY)
        let bottomRight = Point(rect.maxX, -rect.maxY)

        context.drawLine(start: topLeft, end: topRight, lineWidth: 1, color: color)
        context.drawLine(start: topLeft, end: bottomLeft, lineWidth: 1, color: color)
        context.drawLine(start: topRight, end: bottomRight, lineWidth: 1, color: color)
        context.drawLine(start: bottomLeft, end: bottomRight, lineWidth: 1, color: color)
    }

    func textContentRect() -> Rect {
        Rect(
            x: Constants.horizontalInset,
            y: Constants.verticalInset,
            width: max(0, self.frame.width - Constants.horizontalInset * 2),
            height: max(0, self.frame.height - Constants.verticalInset * 2)
        )
    }

    func textRect() -> Rect {
        let content = self.textContentRect()
        return Rect(
            x: content.origin.x + Constants.gutterWidth + Constants.gutterSpacing,
            y: content.origin.y,
            width: max(0, content.width - Constants.gutterWidth - Constants.gutterSpacing),
            height: content.height
        )
    }

    func visualAbsoluteContentRect() -> Rect {
        let absoluteFrame = self.visualAbsoluteFrame()
        return Rect(
            x: absoluteFrame.origin.x + Constants.horizontalInset,
            y: absoluteFrame.origin.y + Constants.verticalInset,
            width: max(0, self.frame.width - Constants.horizontalInset * 2),
            height: max(0, self.frame.height - Constants.verticalInset * 2)
        )
    }

    func convertPointFromRoot(_ point: Point) -> Point {
        var convertedPoint = point
        var node: ViewNode = self

        while let parent = node.parent {
            convertedPoint = node.convert(convertedPoint, from: parent)
            node = parent
        }

        return convertedPoint
    }

    func requestDisplay() {
        self.invalidateNearestLayer()
        self.owner?.containerView?.setNeedsDisplay(in: self.absoluteFrame())
    }

    func resetCaretBlink() {
        self.caretBlinkElapsed = 0
        if !self.caretVisible {
            self.caretVisible = true
            self.requestDisplay()
        }
    }

    func resolvedFontPointSize() -> Float {
        if let font = self.environment.font {
            return Float(font.pointSize)
        }
        return 14
    }

    func resolvedFontForRendering() -> Font? {
        if let font = self.environment.font {
            return font
        }

        if unsafe RenderEngine.shared != nil {
            return .system(size: 14)
        }

        return nil
    }

    func resolvedTextColor() -> Color {
        self.environment.foregroundColor ?? .black
    }

    func characterAdvance(for pointSize: Float) -> Float {
        max(6, pointSize * 0.58)
    }

    func lineHeight(for pointSize: Float) -> Float {
        max(18, pointSize * 1.45)
    }

    static func normalizeInputText(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    static func verticalTextOffset(for layout: TextLayoutManager, height: Float) -> Float {
        guard !layout.textLines.isEmpty else {
            return 0
        }

        var maxTopY: Float = -.infinity
        var minBottomY: Float = .infinity

        for line in layout.textLines {
            for run in line {
                for glyph in run {
                    maxTopY = max(maxTopY, glyph.position.w)
                    minBottomY = min(minBottomY, glyph.position.y)
                }
            }
        }

        guard maxTopY.isFinite, minBottomY.isFinite else {
            return 0
        }

        let textCenterY = (maxTopY + minBottomY) / 2
        let frameCenterY = -height / 2
        return frameCenterY - textCenterY
    }
}
