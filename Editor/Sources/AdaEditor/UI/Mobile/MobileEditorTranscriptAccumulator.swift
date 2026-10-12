import Foundation

/// Joins finalized segments with the current volatile hypothesis.
struct MobileEditorTranscriptAccumulator {
    private(set) var finalized = ""
    private(set) var volatile = ""

    var text: String { Self.join(finalized, volatile) }

    mutating func apply(_ segment: String, isFinal: Bool) -> String {
        if isFinal {
            finalized = Self.join(finalized, segment)
            volatile = ""
        } else {
            volatile = segment
        }
        return text
    }

    private static func join(_ head: String, _ tail: String) -> String {
        guard !head.isEmpty else { return tail }
        guard !tail.isEmpty else { return head }
        let needsSpace = !(head.last?.isWhitespace ?? true) && !(tail.first?.isWhitespace ?? true)
        return needsSpace ? head + " " + tail : head + tail
    }
}
