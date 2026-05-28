@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorCodeFileView: View {
    let document: EditorTextDocument
    let text: Binding<String>
    let fontSize: Double
    let colorPalette: EditorCodeColorPalette
    let onSourceHover: ((EditorTextDocument, EditorSourceLocation?) -> Void)?
    let onGoToDefinition: ((EditorTextDocument, EditorSourceLocation) -> Void)?
    let sourceContextMenuItems: ((EditorTextDocument, EditorSourceLocation) -> [TextEditorContextMenuItem])?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            codeHeader
            if let errorMessage = document.errorMessage {
                fileError(message: errorMessage)
            } else {
                codeEditor
            }
        }
        .background(theme.editorColors.surfaceElevated)
        .accessibilityIdentifier("AdaEditor.CodeFile.\(document.title)")
    }
}

private extension EditorCodeFileView {
    var codeHeader: some View {
        HStack(spacing: 8) {
            Text(document.title)
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.text)
            Text(document.relativePath)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            Spacer()
            if let statusMessage = document.statusMessage {
                Text(statusMessage)
                    .font(.system(size: 10))
                    .foregroundColor(document.isDirty ? theme.editorColors.purple : theme.editorColors.muted)
            }
            Text(document.language.rawValue.uppercased())
                .font(.system(size: 10))
                .foregroundColor(theme.editorColors.blue)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(0.12)))
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(theme.editorColors.surface)
    }

    var codeEditor: some View {
        TextEditor(text: text, tokenSpans: tokenSpans, sourceInteraction: sourceInteraction)
            .font(AdaEditorCodeFont.font(size: fontSize))
            .foregroundColor(theme.editorColors.text)
            .accentColor(theme.editorColors.blue)
            .textEditorColors(editorColors)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var sourceInteraction: TextEditorSourceInteraction? {
        guard document.language == .swift || document.language == .packageManifest else {
            return nil
        }

        return TextEditorSourceInteraction(
            highlightedRanges: document.symbolHighlights.map(\.textEditorRange),
            focusedRange: document.focusedRange?.textEditorRange,
            onHover: { position in
                onSourceHover?(document, position.map { EditorSourceLocation(textEditorPosition: $0) })
            },
            onPrimaryClick: { position in
                onGoToDefinition?(document, EditorSourceLocation(textEditorPosition: position))
            },
            contextMenuItems: { position in
                sourceContextMenuItems?(document, EditorSourceLocation(textEditorPosition: position)) ?? []
            }
        )
    }

    var tokenSpans: [TextEditorTokenSpan] {
        if document.semanticTokens.isEmpty {
            return EditorSyntaxHighlighter.spans(for: document.content, language: document.language, palette: colorPalette)
        }

        return document.semanticTokens.map { token in
            TextEditorTokenSpan(
                line: token.line,
                startColumn: token.startCharacter,
                length: token.length,
                color: color(for: token)
            )
        }
    }

    var editorColors: TextEditorColors {
        TextEditorColors(
            background: theme.editorColors.surfaceElevated,
            border: theme.editorColors.border.opacity(0.55),
            focusedBorder: theme.editorColors.blue,
            gutter: theme.editorColors.muted,
            gutterRule: theme.editorColors.border.opacity(0.45),
            currentLineBackground: theme.editorColors.blue.opacity(0.12),
            selection: theme.editorColors.blue.opacity(0.26)
        )
    }

    func fileError(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unable to open file")
                .font(.system(size: 13))
                .foregroundColor(theme.editorColors.text)
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func color(for token: EditorSemanticToken) -> Color {
        switch token.type {
        case "keyword", "macro":
            colorPalette.keyword
        case "class", "enum", "interface", "struct", "type", "typeParameter":
            colorPalette.type
        case "string":
            colorPalette.string
        case "number":
            colorPalette.number
        case "comment":
            colorPalette.comment
        case "operator":
            colorPalette.punctuation
        default:
            colorPalette.plainText
        }
    }
}

private extension EditorSourceLocation {
    init(textEditorPosition: TextEditorSourcePosition) {
        self.init(line: textEditorPosition.line, character: textEditorPosition.column)
    }

    var textEditorPosition: TextEditorSourcePosition {
        TextEditorSourcePosition(line: line, column: character)
    }
}

private extension EditorSourceRange {
    var textEditorRange: TextEditorSourceRange {
        TextEditorSourceRange(start: start.textEditorPosition, end: end.textEditorPosition)
    }
}

enum AdaEditorCodeFont {
    private static let resource: FontResource? = {
        guard let fontURL = Foundation.Bundle.editor.url(
            forResource: "FiraCode-Regular",
            withExtension: "ttf",
            subdirectory: "Assets/Fonts"
        ) else {
            return nil
        }

        return FontResource.custom(
            fontPath: fontURL,
            emFontScale: 74,
            includeDefaultCharset: true,
            additionalCodepoints: []
        )
    }()

    static func font(size: Double) -> Font {
        guard let resource else {
            return .system(size: size)
        }

        return Font(fontResource: resource, pointSize: size)
    }
}

struct EditorCodeToken: Equatable {
    var text: String
    var color: Color
}

enum EditorSyntaxHighlighter {
    private enum ScanState {
        case normal
        case swiftBlockComment
        case swiftMultilineString
    }

    static func tokens(for source: String, language: EditorSourceLanguage, palette: EditorCodeColorPalette) -> [EditorCodeToken] {
        spans(for: source, language: language, palette: palette).map { span in
            let line = source.components(separatedBy: .newlines)[safe: span.line] ?? ""
            let startIndex = line.index(line.startIndex, offsetBy: min(span.startColumn, line.count))
            let endIndex = line.index(startIndex, offsetBy: min(span.length, line.distance(from: startIndex, to: line.endIndex)))
            return EditorCodeToken(text: String(line[startIndex..<endIndex]), color: span.color)
        }
    }

    static func spans(for source: String, language: EditorSourceLanguage, palette: EditorCodeColorPalette) -> [TextEditorTokenSpan] {
        guard supports(language) else {
            return []
        }

        let lines = source.components(separatedBy: .newlines)
        var state = ScanState.normal
        var spans: [TextEditorTokenSpan] = []

        for (lineIndex, line) in lines.enumerated() {
            switch language {
            case .swift, .packageManifest, .ada:
                spans += swiftSpans(for: line, lineIndex: lineIndex, state: &state, palette: palette)
            case .json:
                spans += jsonSpans(for: line, lineIndex: lineIndex, palette: palette)
            case .yaml:
                spans += yamlSpans(for: line, lineIndex: lineIndex, palette: palette)
            default:
                break
            }
        }

        return spans
    }

    private static func supports(_ language: EditorSourceLanguage) -> Bool {
        switch language {
        case .ada, .json, .packageManifest, .swift, .yaml:
            true
        default:
            false
        }
    }

    private static func swiftSpans(
        for line: String,
        lineIndex: Int,
        state: inout ScanState,
        palette: EditorCodeColorPalette
    ) -> [TextEditorTokenSpan] {
        var spans: [TextEditorTokenSpan] = []
        var column = 0
        let characters = Array(line)

        while column < characters.count {
            if state == .swiftBlockComment {
                let end = find("*/", in: characters, from: column)
                let endColumn = end.map { $0 + 2 } ?? characters.count
                appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.comment, to: &spans)
                column = endColumn
                if end != nil {
                    state = .normal
                }
                continue
            }

            if state == .swiftMultilineString {
                let end = find(#"""""#, in: characters, from: column)
                let endColumn = end.map { $0 + 3 } ?? characters.count
                appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.string, to: &spans)
                column = endColumn
                if end != nil {
                    state = .normal
                }
                continue
            }

            if matches("//", in: characters, at: column) {
                appendSpan(line: lineIndex, start: column, end: characters.count, color: palette.comment, to: &spans)
                break
            }

            if matches("/*", in: characters, at: column) {
                let end = find("*/", in: characters, from: column + 2)
                let endColumn = end.map { $0 + 2 } ?? characters.count
                appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.comment, to: &spans)
                column = endColumn
                if end == nil {
                    state = .swiftBlockComment
                }
                continue
            }

            if matches(#"""""#, in: characters, at: column) {
                let end = find(#"""""#, in: characters, from: column + 3)
                let endColumn = end.map { $0 + 3 } ?? characters.count
                appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.string, to: &spans)
                column = endColumn
                if end == nil {
                    state = .swiftMultilineString
                }
                continue
            }

            if characters[column] == "\"" {
                let endColumn = quotedStringEnd(in: characters, from: column)
                appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.string, to: &spans)
                column = endColumn
                continue
            }

            if isNumberStart(characters, at: column) {
                let endColumn = numberEnd(in: characters, from: column)
                appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.number, to: &spans)
                column = endColumn
                continue
            }

            if isIdentifierStart(characters[column]) {
                let endColumn = identifierEnd(in: characters, from: column)
                let word = String(characters[column..<endColumn])
                if swiftKeywords.contains(word) {
                    appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.keyword, to: &spans)
                } else if word.first?.isUppercase == true {
                    appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.type, to: &spans)
                }
                column = endColumn
                continue
            }

            if swiftPunctuation.contains(characters[column]) {
                appendSpan(line: lineIndex, start: column, end: column + 1, color: palette.punctuation, to: &spans)
            }

            column += 1
        }

        return spans
    }

    private static func jsonSpans(for line: String, lineIndex: Int, palette: EditorCodeColorPalette) -> [TextEditorTokenSpan] {
        var spans: [TextEditorTokenSpan] = []
        var column = 0
        let characters = Array(line)

        while column < characters.count {
            if characters[column] == "\"" {
                let endColumn = quotedStringEnd(in: characters, from: column)
                appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.string, to: &spans)
                column = endColumn
                continue
            }

            if isNumberStart(characters, at: column) {
                let endColumn = numberEnd(in: characters, from: column)
                appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.number, to: &spans)
                column = endColumn
                continue
            }

            if isIdentifierStart(characters[column]) {
                let endColumn = identifierEnd(in: characters, from: column)
                let word = String(characters[column..<endColumn])
                if jsonKeywords.contains(word) {
                    appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.keyword, to: &spans)
                }
                column = endColumn
                continue
            }

            if jsonPunctuation.contains(characters[column]) {
                appendSpan(line: lineIndex, start: column, end: column + 1, color: palette.punctuation, to: &spans)
            }

            column += 1
        }

        return spans
    }

    private static func yamlSpans(for line: String, lineIndex: Int, palette: EditorCodeColorPalette) -> [TextEditorTokenSpan] {
        var spans: [TextEditorTokenSpan] = []
        var column = 0
        let characters = Array(line)

        while column < characters.count {
            if characters[column] == "#" {
                appendSpan(line: lineIndex, start: column, end: characters.count, color: palette.comment, to: &spans)
                break
            }

            if characters[column] == "\"" || characters[column] == "'" {
                let endColumn = quotedStringEnd(in: characters, from: column)
                appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.string, to: &spans)
                column = endColumn
                continue
            }

            if isNumberStart(characters, at: column) {
                let endColumn = numberEnd(in: characters, from: column)
                appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.number, to: &spans)
                column = endColumn
                continue
            }

            if isIdentifierStart(characters[column]) {
                let endColumn = yamlIdentifierEnd(in: characters, from: column)
                let word = String(characters[column..<endColumn])
                let nextNonSpace = characters[endColumn...].firstIndex { !$0.isWhitespace }
                if nextNonSpace.map({ characters[$0] == ":" }) == true {
                    appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.type, to: &spans)
                } else if yamlKeywords.contains(word.lowercased()) {
                    appendSpan(line: lineIndex, start: column, end: endColumn, color: palette.keyword, to: &spans)
                }
                column = endColumn
                continue
            }

            if yamlPunctuation.contains(characters[column]) {
                appendSpan(line: lineIndex, start: column, end: column + 1, color: palette.punctuation, to: &spans)
            }

            column += 1
        }

        return spans
    }

    private static func appendSpan(line: Int, start: Int, end: Int, color: Color, to spans: inout [TextEditorTokenSpan]) {
        guard start < end else {
            return
        }

        spans.append(TextEditorTokenSpan(line: line, startColumn: start, length: end - start, color: color))
    }

    private static func matches(_ needle: String, in characters: [Character], at index: Int) -> Bool {
        let needleCharacters = Array(needle)
        guard index + needleCharacters.count <= characters.count else {
            return false
        }

        return Array(characters[index..<index + needleCharacters.count]) == needleCharacters
    }

    private static func find(_ needle: String, in characters: [Character], from index: Int) -> Int? {
        guard index < characters.count else {
            return nil
        }

        for offset in index..<characters.count where matches(needle, in: characters, at: offset) {
            return offset
        }

        return nil
    }

    private static func quotedStringEnd(in characters: [Character], from start: Int) -> Int {
        let quote = characters[start]
        var index = start + 1
        var isEscaped = false

        while index < characters.count {
            let character = characters[index]
            if isEscaped {
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == quote {
                return index + 1
            }
            index += 1
        }

        return characters.count
    }

    private static func numberEnd(in characters: [Character], from start: Int) -> Int {
        var index = start
        if characters[index] == "-" {
            index += 1
        }

        while index < characters.count, characters[index].isNumber {
            index += 1
        }

        if index < characters.count, characters[index] == "." {
            index += 1
            while index < characters.count, characters[index].isNumber {
                index += 1
            }
        }

        if index < characters.count, characters[index] == "e" || characters[index] == "E" {
            index += 1
            if index < characters.count, characters[index] == "+" || characters[index] == "-" {
                index += 1
            }
            while index < characters.count, characters[index].isNumber {
                index += 1
            }
        }

        return index
    }

    private static func identifierEnd(in characters: [Character], from start: Int) -> Int {
        var index = start
        while index < characters.count, isIdentifierPart(characters[index]) {
            index += 1
        }
        return index
    }

    private static func yamlIdentifierEnd(in characters: [Character], from start: Int) -> Int {
        var index = start
        while index < characters.count, isYAMLIdentifierPart(characters[index]) {
            index += 1
        }
        return index
    }

    private static func isNumberStart(_ characters: [Character], at index: Int) -> Bool {
        characters[index].isNumber || (characters[index] == "-" && index + 1 < characters.count && characters[index + 1].isNumber)
    }

    private static func isIdentifierStart(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    private static func isIdentifierPart(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private static func isYAMLIdentifierPart(_ character: Character) -> Bool {
        isIdentifierPart(character) || character == "-" || character == "."
    }

    private static let swiftKeywords: Set<String> = [
        "actor", "as", "async", "await", "break", "case", "catch", "class", "continue", "default", "defer", "do", "else", "enum", "extension",
        "fallthrough", "false", "for", "func", "guard", "if", "import", "in", "init", "inout", "is", "let", "nil", "operator", "private",
        "protocol", "public", "repeat", "return", "self", "some", "static", "struct", "subscript", "super", "switch", "throw", "throws", "true",
        "try", "typealias", "var", "where", "while"
    ]

    private static let jsonKeywords: Set<String> = ["false", "null", "true"]
    private static let yamlKeywords: Set<String> = ["false", "no", "null", "off", "on", "true", "yes"]
    private static let swiftPunctuation = Set("()[]{}.,:;+-*/%=!<>?&|@")
    private static let jsonPunctuation = Set("{}[]:,")
    private static let yamlPunctuation = Set("[]{}:,-")
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
