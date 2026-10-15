import Foundation

/// Gives every test assertion its call-site location (ADR-0024).
///
/// Ada Script has no way to ask where a call came from, so `expect(x)` becomes
/// `__adaTest_expect("Main.ada:12:5", x)` before Gravity sees the source. Offsets of everything after an edit
/// shift, so edits apply from the end and the pass runs on already import-lowered text.
public enum AdaScriptTestLowerer {
    /// The assertion names that take a location.
    public static let assertionNames: Set<String> = ["expect", "expectEqual", "expectNear", "expectNil", "fail", "require"]

    /// - Parameter declared: Names the module declares itself; a project's own `fail` is left alone.
    public static func lower(source: String, path: String, declared: Set<String>) -> String {
        var lexer = AdaScriptAnalysisLexer(source: source)
        let tokens = lexer.lex().filter { $0.kind != .comment }
        let location = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var edits: [(offsets: Range<Int>, text: String)] = []
        for index in tokens.indices {
            let token = tokens[index]
            guard
                token.kind == .identifier, assertionNames.contains(token.text), !declared.contains(token.text),
                index + 1 < tokens.count, tokens[index + 1].text == "(",
                !(index > 0 && (tokens[index - 1].text == "." || tokens[index - 1].text == "func"))
            else {
                continue
            }
            let start = token.range.start
            let literal = "\"\(location):\(start.line + 1):\(start.utf16Column + 1)\""
            let hasArguments = index + 2 < tokens.count && tokens[index + 2].text != ")"
            edits.append((token.startOffset..<tokens[index + 1].endOffset, "__adaTest_\(token.text)(" + literal + (hasArguments ? ", " : "")))
        }
        guard !edits.isEmpty else {
            return source
        }
        var characters = Array(source)
        for edit in edits.sorted(by: { $0.offsets.lowerBound > $1.offsets.lowerBound }) {
            characters.replaceSubrange(edit.offsets, with: Array(edit.text))
        }
        return String(characters)
    }
}
