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
        "AdaPlugin": [
            GravityCompletionCandidate(
                detail: "Create an AdaEngine script plugin",
                insertText: "create(\"Plugin\", [])",
                kind: .method,
                label: "create(name, systems)",
                sortText: "00"
            )
        ],
        "AdaQuery": [
            GravityCompletionCandidate(detail: "Read-only ECS query", insertText: "read([])", kind: .method, label: "read(components)", sortText: "00"),
            GravityCompletionCandidate(detail: "Writable ECS query", insertText: "write([])", kind: .method, label: "write(components)", sortText: "01"),
            GravityCompletionCandidate(
                detail: "ECS query with explicit writes",
                insertText: "readWrite([], [])",
                kind: .method,
                label: "readWrite(components, writeComponents)",
                sortText: "02"
            )
        ],
        "AdaSystem": [
            GravityCompletionCandidate(
                detail: "Create an entity-based Ada system",
                insertText: "create(\"system.id\", \"update\", [], System())",
                kind: .method,
                label: "create(identifier, scheduler, queries, instance)",
                sortText: "00"
            ),
            GravityCompletionCandidate(
                detail: "Create a batch Ada system",
                insertText: "createBatch(\"system.id\", \"update\", [], System())",
                kind: .method,
                label: "createBatch(identifier, scheduler, queries, instance)",
                sortText: "01"
            )
        ],
        "$AdaEntity": [
            GravityCompletionCandidate(detail: "Entity identifier", insertText: "id", kind: .property, label: "id", sortText: "00"),
            GravityCompletionCandidate(
                detail: "Read a declared ECS field",
                insertText: "get(\"Component\", \"field\")",
                kind: .method,
                label: "get(component, field)",
                sortText: "01"
            ),
            GravityCompletionCandidate(
                detail: "Write a declared ECS field",
                insertText: "set(\"Component\", \"field\", value)",
                kind: .method,
                label: "set(component, field, value)",
                sortText: "02"
            )
        ],
        "$AdaQueryCollection": [
            GravityCompletionCandidate(detail: "Number of matched entities", insertText: "count", kind: .property, label: "count", sortText: "00"),
            GravityCompletionCandidate(detail: "Entity identifier at index", insertText: "id(index)", kind: .method, label: "id(index)", sortText: "01"),
            GravityCompletionCandidate(
                detail: "Read a declared ECS field at index",
                insertText: "get(index, \"Component\", \"field\")",
                kind: .method,
                label: "get(index, component, field)",
                sortText: "02"
            ),
            GravityCompletionCandidate(
                detail: "Write a declared ECS field at index",
                insertText: "set(index, \"Component\", \"field\", value)",
                kind: .method,
                label: "set(index, component, field, value)",
                sortText: "03"
            )
        ]
    ]

    static let globalCandidates: [GravityCompletionCandidate] = [
        GravityCompletionCandidate(detail: "AdaEngine Gravity API", insertText: "AdaPlugin", kind: .class, label: "AdaPlugin", sortText: "00"),
        GravityCompletionCandidate(detail: "AdaEngine Gravity API", insertText: "AdaQuery", kind: .class, label: "AdaQuery", sortText: "01"),
        GravityCompletionCandidate(detail: "AdaEngine Gravity API", insertText: "AdaSystem", kind: .class, label: "AdaSystem", sortText: "02"),
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
