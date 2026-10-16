import AdaInput

/// Stores marked text in UTF-16 units, independently of grapheme-based UI carets.
/// A combining mark can join the preceding Character without becoming its owner.
struct TextInputComposition {
    var range: Range<Int>?
    private var anchorUTF16: Int?
    private var caretUTF16: Int?

    struct Edit {
        var text: String
        var anchor: Int
        var head: Int
    }

    mutating func apply(_ event: TextInputEvent, text: String, selectionAnchor: Int, selectionHead: Int, insertedText: String) -> Edit {
        var units = Array(text.utf16)
        let anchor = anchorUTF16 ?? Self.utf16Offset(selectionAnchor, in: text)
        let caret = caretUTF16 ?? Self.utf16Offset(selectionHead, in: text)
        let selected = min(anchor, caret)..<max(anchor, caret)
        var nextAnchor = anchor
        var nextHead = caret
        switch event.action {
        case .setComposingText, .commitText:
            let replaced = range ?? selected
            let inserted = Array(insertedText.utf16)
            units.replaceSubrange(replaced, with: inserted)
            range = event.action == .setComposingText && !inserted.isEmpty ? replaced.lowerBound..<(replaced.lowerBound + inserted.count) : nil
            let offset = event.cursorOffset > 0
                ? replaced.lowerBound + inserted.count + event.cursorOffset - 1
                : replaced.lowerBound + event.cursorOffset
            let clamped = max(0, min(units.count, offset))
            nextAnchor = clamped
            nextHead = clamped
        case .finishComposingText:
            range = nil
        case .setComposingRegion, .setSelection:
            let start = max(0, min(units.count, caret + event.rangeStart))
            let end = max(0, min(units.count, caret + event.rangeEnd))
            if event.action == .setComposingRegion {
                range = start == end ? nil : min(start, end)..<max(start, end)
            } else {
                nextAnchor = start
                nextHead = end
            }
        case .deleteSurroundingText, .deleteSurroundingTextInCodePoints:
            let protected = range.map { min($0.lowerBound, selected.lowerBound)..<max($0.upperBound, selected.upperBound) } ?? selected
            let codePoints = event.action == .deleteSurroundingTextInCodePoints
            let start = Self.deletionBoundary(in: units, from: protected.lowerBound, count: event.rangeStart, backwards: true, codePoints: codePoints)
            let end = Self.deletionBoundary(in: units, from: protected.upperBound, count: event.rangeEnd, backwards: false, codePoints: codePoints)
            units.removeSubrange(protected.upperBound..<end)
            units.removeSubrange(start..<protected.lowerBound)
            let removedBefore = protected.lowerBound - start
            if let marked = range { range = (marked.lowerBound - removedBefore)..<(marked.upperBound - removedBefore) }
            nextAnchor = anchor - removedBefore
            nextHead = caret - removedBefore
        case .insert, .deleteBackward:
            break
        }
        let result = String(decoding: units, as: UTF16.self)
        anchorUTF16 = nextAnchor
        caretUTF16 = nextHead
        return Edit(
            text: result,
            anchor: Self.characterOffset(nextAnchor, in: result),
            head: Self.characterOffset(nextHead, in: result)
        )
    }

    private static func utf16Offset(_ offset: Int, in text: String) -> Int {
        let index = text.index(text.startIndex, offsetBy: min(text.count, max(0, offset)))
        return index.utf16Offset(in: text)
    }

    /// UI caret offsets must round to a Character boundary, while the marked
    /// range retains the exact scalar boundary for subsequent replacement.
    private static func characterOffset(_ utf16Offset: Int, in text: String) -> Int {
        var count = 0
        var consumed = 0
        for character in text {
            if consumed >= utf16Offset { break }
            consumed += character.utf16.count
            count += 1
        }
        return count
    }

    private static func deletionBoundary(in units: [UInt16], from offset: Int, count: Int, backwards: Bool, codePoints: Bool) -> Int {
        var result = offset
        for _ in 0..<max(0, min(count, units.count)) {
            if backwards {
                guard result > 0 else { break }
                result -= 1
                if codePoints, result > 0, (0xDC00...0xDFFF).contains(units[result]), (0xD800...0xDBFF).contains(units[result - 1]) { result -= 1 }
            } else {
                guard result < units.count else { break }
                result += 1
                if codePoints, result < units.count, (0xD800...0xDBFF).contains(units[result - 1]), (0xDC00...0xDFFF).contains(units[result]) { result += 1 }
            }
        }
        // UTF-16 deletion must never leave an unpaired surrogate in Swift text.
        if result > 0, result < units.count, (0xD800...0xDBFF).contains(units[result - 1]), (0xDC00...0xDFFF).contains(units[result]) {
            result += backwards ? -1 : 1
        }
        return result
    }
}
