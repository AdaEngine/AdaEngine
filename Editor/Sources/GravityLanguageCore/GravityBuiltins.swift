import Foundation

struct GravityCompletionCandidate: Hashable, Sendable {
    var detail: String
    var insertText: String
    var kind: GravityCompletionKind
    var label: String
    var sortText: String

    init(detail: String, insertText: String, kind: GravityCompletionKind, label: String, sortText: String) {
        self.detail = detail
        self.insertText = insertText
        self.kind = kind
        self.label = label
        self.sortText = sortText
    }

    init(symbol: GravitySymbol) {
        kind = switch symbol.kind {
        case .class: .class
        case .enum: .enum
        case .function: .function
        case .method: .method
        case .struct: .struct
        case .field, .property: .property
        default: .variable
        }
        detail = symbol.detail
        insertText = switch symbol.kind {
        case .function, .method: "\(symbol.name)()"
        default: symbol.name
        }
        label = symbol.name
        sortText = symbol.kind == .class || symbol.kind == .struct || symbol.kind == .enum ? "20" : "21"
    }
}

enum GravityBuiltins {
    static let members: [String: [GravityCompletionCandidate]] = [
        "$AdaEntity": [
            GravityCompletionCandidate(detail: "Entity identifier", insertText: "id", kind: .property, label: "id", sortText: "00")
        ]
    ]

    static let annotationCandidates: [GravityCompletionCandidate] = [
        GravityCompletionCandidate(
            detail: "Declare an AdaEngine ECS system",
            insertText: "system(scheduler: \"update\")",
            kind: .keyword,
            label: "system",
            sortText: "00"
        ),
        GravityCompletionCandidate(
            detail: "Declare an iterator-based ECS query",
            insertText: "query()",
            kind: .keyword,
            label: "query",
            sortText: "01"
        ),
        GravityCompletionCandidate(
            detail: "Declare explicit scheduler access",
            insertText: "access(read: [], write: [])",
            kind: .keyword,
            label: "access",
            sortText: "02"
        ),
        GravityCompletionCandidate(
            detail: "Declare an Ada Script component",
            insertText: "component(id: \"\")",
            kind: .keyword,
            label: "component",
            sortText: "03"
        ),
        GravityCompletionCandidate(
            detail: "Declare an Ada Script resource",
            insertText: "resource(id: \"\")",
            kind: .keyword,
            label: "resource",
            sortText: "04"
        )
    ]

    static let globalCandidates: [GravityCompletionCandidate] = [
        GravityCompletionCandidate(detail: "Function declaration", insertText: "func name() {\n    \n}", kind: .snippet, label: "func", sortText: "10"),
        GravityCompletionCandidate(detail: "Class declaration", insertText: "class Name {\n    \n}", kind: .snippet, label: "class", sortText: "11"),
        GravityCompletionCandidate(detail: "Variable declaration", insertText: "var ", kind: .keyword, label: "var", sortText: "12"),
        GravityCompletionCandidate(detail: "Return statement", insertText: "return ", kind: .keyword, label: "return", sortText: "13"),
        GravityCompletionCandidate(detail: "Conditional statement", insertText: "if () {\n    \n}", kind: .snippet, label: "if", sortText: "14"),
        GravityCompletionCandidate(detail: "Alternative branch", insertText: "else {\n    \n}", kind: .snippet, label: "else", sortText: "15"),
        GravityCompletionCandidate(detail: "For loop", insertText: "for (item in items) {\n    \n}", kind: .snippet, label: "for", sortText: "16"),
        GravityCompletionCandidate(detail: "While loop", insertText: "while () {\n    \n}", kind: .snippet, label: "while", sortText: "17")
    ] + keywordCandidates

    private static let keywordCandidates = [
        "break", "case", "const", "continue", "enum", "event", "extern", "false", "import", "null", "private", "public", "repeat", "static", "struct", "switch", "true"
    ].enumerated().map { index, keyword in
        GravityCompletionCandidate(detail: "Gravity keyword", insertText: keyword, kind: .keyword, label: keyword, sortText: "\(30 + index)")
    }
}
