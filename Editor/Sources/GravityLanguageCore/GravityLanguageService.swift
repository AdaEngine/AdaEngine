import Foundation

public struct GravityLanguageService: Sendable {
    public init() {}

    public func analyze(text: String) -> GravityDocumentAnalysis {
        GravityDocumentAnalyzer.parse(text).analysis
    }

    public func completions(
        text: String,
        position: GravitySourcePosition,
        workspaceSymbols: [GravitySymbol] = []
    ) -> [GravityCompletion] {
        guard let context = GravityCompletionContext(text: text, position: position) else {
            return []
        }
        let parsed = GravityDocumentAnalyzer.parse(text)
        guard !parsed.tokens.contains(where: { token in
            (token.kind == .comment || token.kind == .string) && token.range.start <= position && position <= token.range.end
        }) else {
            return []
        }

        let symbols = (parsed.analysis.symbols + workspaceSymbols).uniqued(on: { "\($0.kind.rawValue):\($0.name)" })
        let candidates: [GravityCompletionCandidate]
        if let receiver = context.receiver {
            candidates = memberCandidates(receiver: receiver, position: position, parsed: parsed, symbols: symbols)
        } else {
            candidates = GravityBuiltins.globalCandidates + symbols.map(GravityCompletionCandidate.init(symbol:))
        }

        return candidates
            .filter { context.prefix.isEmpty || $0.label.localizedCaseInsensitiveContains(context.prefix) }
            .uniqued(on: \.label)
            .sorted { lhs, rhs in
                let prefix = context.prefix.lowercased()
                let lhsStartsWithPrefix = lhs.label.lowercased().hasPrefix(prefix)
                let rhsStartsWithPrefix = rhs.label.lowercased().hasPrefix(prefix)
                if lhsStartsWithPrefix != rhsStartsWithPrefix {
                    return lhsStartsWithPrefix
                }
                if lhs.sortText != rhs.sortText {
                    return lhs.sortText < rhs.sortText
                }
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
            .map { candidate in
                GravityCompletion(
                    label: candidate.label,
                    detail: candidate.detail,
                    insertText: candidate.insertText,
                    kind: candidate.kind,
                    replacementRange: context.replacementRange,
                    sortText: candidate.sortText
                )
            }
    }

    private func memberCandidates(
        receiver: String,
        position: GravitySourcePosition,
        parsed: GravityParsedDocument,
        symbols: [GravitySymbol]
    ) -> [GravityCompletionCandidate] {
        if let builtins = GravityBuiltins.members[receiver] {
            return builtins
        }
        if receiver == "this", let containingType = GravityDocumentAnalyzer.typeContaining(position, in: parsed.typeRegions) {
            return containingType.members.map(GravityCompletionCandidate.init(symbol:))
        }

        let inferredType = parsed.inferredTypes[receiver] ?? receiver
        if let builtins = GravityBuiltins.members[inferredType] {
            return builtins
        }
        return symbols.first(where: { $0.name == inferredType && !$0.members.isEmpty })?.members.map(GravityCompletionCandidate.init(symbol:)) ?? []
    }
}

private struct GravityCompletionContext {
    var prefix: String
    var receiver: String?
    var replacementRange: GravitySourceRange

    init?(text: String, position: GravitySourcePosition) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.indices.contains(position.line) else {
            return nil
        }
        let line = String(lines[position.line])
        guard let caretIndex = line.stringIndex(atUTF16Offset: position.utf16Column) else {
            return nil
        }
        var prefixStart = caretIndex
        while prefixStart > line.startIndex {
            let previous = line.index(before: prefixStart)
            let character = line[previous]
            guard character == "_" || character.isLetter || character.isNumber else {
                break
            }
            prefixStart = previous
        }
        prefix = String(line[prefixStart..<caretIndex])
        let prefixStartColumn = line[..<prefixStart].utf16.count
        replacementRange = GravitySourceRange(
            start: GravitySourcePosition(line: position.line, utf16Column: prefixStartColumn),
            end: position
        )

        guard prefixStart > line.startIndex else {
            receiver = nil
            return
        }
        let dotIndex = line.index(before: prefixStart)
        guard line[dotIndex] == "." else {
            receiver = nil
            return
        }
        var receiverStart = dotIndex
        while receiverStart > line.startIndex {
            let previous = line.index(before: receiverStart)
            let character = line[previous]
            guard character == "_" || character.isLetter || character.isNumber else {
                break
            }
            receiverStart = previous
        }
        let value = String(line[receiverStart..<dotIndex])
        receiver = value.isEmpty ? nil : value
    }
}

private extension String {
    func stringIndex(atUTF16Offset offset: Int) -> String.Index? {
        guard offset >= 0,
              let utf16Index = utf16.index(utf16.startIndex, offsetBy: offset, limitedBy: utf16.endIndex)
        else {
            return nil
        }
        return Self.Index(utf16Index, within: self)
    }
}

private extension Sequence {
    func uniqued<Key: Hashable>(on key: (Element) -> Key) -> [Element] {
        var seen: Set<Key> = []
        return filter { seen.insert(key($0)).inserted }
    }
}
