//
//  TextEditorViewNode+Navigation.swift
//  AdaEngine
//
//  Created by Codex on 18.05.2026.
//

import Foundation
import Math

extension TextEditorViewNode {

    func lines() -> [LineInfo] {
        var result: [LineInfo] = []
        var current = ""
        var startOffset = 0
        var offset = 0

        for character in self.text {
            if character == "\n" {
                result.append(LineInfo(text: current, startOffset: startOffset))
                current = ""
                offset += 1
                startOffset = offset
            } else {
                current.append(character)
                offset += 1
            }
        }

        result.append(LineInfo(text: current, startOffset: startOffset))
        return result
    }

    func position(forOffset offset: Int, lines: [LineInfo]) -> TextPosition {
        let clamped = max(0, min(offset, self.text.count))
        var bestLine = 0

        for index in lines.indices {
            let line = lines[index]
            let lineEndOffset = line.startOffset + line.text.count
            if clamped <= lineEndOffset {
                return TextPosition(line: index, column: clamped - line.startOffset)
            }
            bestLine = index
        }

        let fallback = lines[bestLine]
        return TextPosition(line: bestLine, column: fallback.text.count)
    }

    func offset(line: Int, column: Int, lines: [LineInfo]) -> Int {
        guard !lines.isEmpty else {
            return 0
        }

        let lineIndex = max(0, min(line, lines.count - 1))
        return lines[lineIndex].startOffset + max(0, min(column, lines[lineIndex].text.count))
    }

    func closestOffset(to point: Point) -> Int {
        let lines = self.lines()
        let textRect = self.textRect()
        let pointSize = self.resolvedFontPointSize()
        let lineHeight = self.lineHeight(for: pointSize)
        let characterAdvance = self.characterAdvance(for: pointSize)

        let y = max(0, point.y - textRect.origin.y + self.scrollOffset.y)
        let x = max(0, point.x - textRect.origin.x + self.scrollOffset.x)
        let line = max(0, min(Int(y / max(1, lineHeight)), lines.count - 1))
        let column = max(0, min(Int((x / characterAdvance).rounded()), lines[line].text.count))
        return self.offset(line: line, column: column, lines: lines)
    }

    func wordBoundaryBefore(offset: Int) -> Int {
        let characters = Array(self.text)
        var index = max(0, min(offset, characters.count))
        guard index > 0 else {
            return 0
        }

        while index > 0, !Self.isWordCharacter(characters[index - 1]) {
            index -= 1
        }

        while index > 0, Self.isWordCharacter(characters[index - 1]) {
            index -= 1
        }

        return index
    }

    func wordBoundaryAfter(offset: Int) -> Int {
        let characters = Array(self.text)
        let count = characters.count
        var index = max(0, min(offset, count))
        guard index < count else {
            return count
        }

        while index < count, !Self.isWordCharacter(characters[index]) {
            index += 1
        }

        while index < count, Self.isWordCharacter(characters[index]) {
            index += 1
        }

        return index
    }

    static func isWordCharacter(_ character: Character) -> Bool {
        var hasScalars = false
        for scalar in character.unicodeScalars {
            hasScalars = true
            if scalar == "_" {
                continue
            }

            if !CharacterSet.alphanumerics.contains(scalar) {
                return false
            }
        }

        return hasScalars
    }

    func ensureCaretVisibleIfNeeded() {
        let lines = self.lines()
        let position = self.position(forOffset: self.caretOffset, lines: lines)
        let pointSize = self.resolvedFontPointSize()
        let lineHeight = self.lineHeight(for: pointSize)
        let characterAdvance = self.characterAdvance(for: pointSize)
        let textRect = self.textRect()

        let caretX = Float(position.column) * characterAdvance
        let caretY = Float(position.line) * lineHeight

        if caretX < self.scrollOffset.x {
            self.scrollOffset.x = caretX
        } else if caretX > self.scrollOffset.x + textRect.width - characterAdvance {
            self.scrollOffset.x = caretX - textRect.width + characterAdvance
        }

        if caretY < self.scrollOffset.y {
            self.scrollOffset.y = caretY
        } else if caretY + lineHeight > self.scrollOffset.y + textRect.height {
            self.scrollOffset.y = caretY + lineHeight - textRect.height
        }

        self.clampScrollOffset(lines: lines)
    }

    func scroll(by delta: Point) {
        self.scrollOffset.x += delta.x
        self.scrollOffset.y += delta.y
        self.clampScrollOffset(lines: self.lines())
        self.requestDisplay()
    }

    func clampScrollOffset(lines: [LineInfo]) {
        let pointSize = self.resolvedFontPointSize()
        let lineHeight = self.lineHeight(for: pointSize)
        let maxLineWidth = Float(lines.map(\.text.count).max() ?? 0) * self.characterAdvance(for: pointSize)
        let textRect = self.textRect()
        let contentHeight = Float(lines.count) * lineHeight

        self.scrollOffset.x = max(0, min(self.scrollOffset.x, max(0, maxLineWidth - textRect.width)))
        self.scrollOffset.y = max(0, min(self.scrollOffset.y, max(0, contentHeight - textRect.height)))
    }

    func visibleLineRange(lineHeight: Float, viewportHeight: Float) -> Range<Int> {
        let lines = self.lines()
        let firstLine = max(0, Int(self.scrollOffset.y / max(1, lineHeight)))
        let visibleCount = max(1, Int(ceil(viewportHeight / max(1, lineHeight))) + 2)
        return firstLine..<min(lines.count, firstLine + visibleCount)
    }

    func isTap(at position: Point, start: Point?) -> Bool {
        guard let start else {
            return false
        }

        let dx = position.x - start.x
        let dy = position.y - start.y
        return dx * dx + dy * dy <= Constants.tapMovementToleranceSquared
    }
}
