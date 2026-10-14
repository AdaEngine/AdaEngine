/// One `import` declaration, parsed once and shared by the runtime resolver, the build
/// generator, and the Editor language service.
public struct AdaScriptImportSyntax: Equatable, Hashable, Sendable {
    /// One imported name, optionally renamed with `as`.
    public struct Binding: Equatable, Hashable, Sendable {
        public var alias: String?
        public var name: String
        public var range: AdaScriptSourceRange

        public init(alias: String? = nil, name: String, range: AdaScriptSourceRange) {
            self.alias = alias
            self.name = name
            self.range = range
        }

        /// The name the importing module uses.
        public var localName: String { alias ?? name }
    }

    public enum Kind: Equatable, Hashable, Sendable {
        /// `import { A, B as C } from "path";`
        case selected([Binding])
        /// `import * as Alias from "path";`
        case namespace(alias: String)
    }

    public var kind: Kind
    /// Character offsets of the whole declaration, for blanking it out of the source.
    public var offsets: Range<Int>
    public var path: String
    public var pathRange: AdaScriptSourceRange
    public var range: AdaScriptSourceRange

    public init(kind: Kind, offsets: Range<Int>, path: String, pathRange: AdaScriptSourceRange, range: AdaScriptSourceRange) {
        self.kind = kind
        self.offsets = offsets
        self.path = path
        self.pathRange = pathRange
        self.range = range
    }

    /// Names brought in by a selected import; empty for a namespace import.
    public var importedNames: [String] {
        guard case let .selected(bindings) = kind else {
            return []
        }
        return bindings.map(\.name)
    }

    /// The namespace alias, or `nil` for a selected import.
    public var namespace: String? {
        guard case let .namespace(alias) = kind else {
            return nil
        }
        return alias
    }
}

/// A malformed import, positioned at the offending token.
public struct AdaScriptImportDiagnostic: Equatable, Hashable, Sendable {
    public var message: String
    public var range: AdaScriptSourceRange

    public init(message: String, range: AdaScriptSourceRange) {
        self.message = message
        self.range = range
    }
}

/// Who may see a top-level declaration from another module.
public enum AdaScriptDeclarationVisibility: String, Equatable, Hashable, Sendable {
    /// Importable by name. The default for a declaration without a modifier.
    case `public`
    /// Module-local: never importable.
    case `private`
}

/// One `@name` use and the declaration it is attached to, for validating annotation placement.
public struct AdaScriptAnnotationUse: Equatable, Hashable, Sendable {
    public enum Target: Equatable, Hashable, Sendable {
        case `class`
        case `enum`
        case `struct`
        case function
        /// A `func` declared inside a type.
        case method
        /// A `var`/`const` declared inside a type.
        case property
        /// A top-level `var`/`const`.
        case variable
        case parameter
        /// Not attached to a declaration (for example the file-level `@strict`).
        case module
    }

    public var name: String
    public var range: AdaScriptSourceRange
    public var target: Target
    /// The declaration's own name, when it has one.
    public var targetName: String?
    /// The enclosing type for a method or property.
    public var parentName: String?

    public init(
        name: String,
        range: AdaScriptSourceRange,
        target: Target,
        targetName: String? = nil,
        parentName: String? = nil
    ) {
        self.name = name
        self.range = range
        self.target = target
        self.targetName = targetName
        self.parentName = parentName
    }
}

/// A reference to an import name inside a module body, used to validate and lower qualified and
/// renamed imports.
public struct AdaScriptImportUse: Equatable, Hashable, Sendable {
    public enum Kind: Equatable, Hashable, Sendable {
        /// `Alias.member` through `import * as Alias`.
        case namespaceMember(alias: String, member: String)
        /// A bare use of a name imported with `as`.
        case renamed(local: String, original: String)
    }

    public var kind: Kind
    /// Character offsets to replace when lowering: the whole `Alias.` prefix, or the renamed identifier.
    public var offsets: Range<Int>
    public var range: AdaScriptSourceRange

    public init(kind: Kind, offsets: Range<Int>, range: AdaScriptSourceRange) {
        self.kind = kind
        self.offsets = offsets
        self.range = range
    }
}

/// The contents of the built-in `AdaEngine` and `AdaUI` modules.
public enum AdaScriptVirtualModules {
    /// Names always available from `AdaEngine`: script-facing engine services and value types.
    /// Native components and resources are registered by the host at runtime, so the module is open.
    public static let adaEngineNames: [String] = [
        "Assets", "Color", "Input", "Math", "Multiplayer", "Saves", "System", "Tasks", "Time", "Vector2", "Vector3", "Vector4",
    ]

    /// Every view the AdaUI module provides.
    public static let adaUINames: [String] = [
        "Button", "Divider", "EmptyView", "HStack", "NativeView", "Spacer", "Text", "VStack", "ZStack",
    ]

    /// Names to offer in completion for `module`.
    public static func knownNames(of module: String) -> [String] {
        switch module {
        case "AdaEngine": adaEngineNames
        case "AdaUI": adaUINames
        default: []
        }
    }

    /// The exact exports of a closed module, or `nil` when the module accepts names the host registers
    /// at runtime (`AdaEngine`) and cannot be checked statically.
    public static func exports(of module: String) -> [String: AdaScriptDeclarationVisibility]? {
        guard module == "AdaUI" else {
            return nil
        }
        return Dictionary(uniqueKeysWithValues: adaUINames.map { ($0, .public) })
    }
}

/// Turns a module's imports into the flat form Gravity compiles.
public enum AdaScriptImportLowering {
    /// Blanks each `import` declaration and top-level access specifier (keeping newlines so later line numbers still match), drops the
    /// `Alias.` qualifier of namespace members, and renames `as`-imported names back to their declaration.
    public static func lower(source: String, tree: AdaScriptSyntaxTree) -> String {
        var edits: [(offsets: Range<Int>, replacement: String?)] = tree.imports.map { ($0.offsets, nil) }
        edits += tree.visibilityModifierOffsets.map { ($0, nil) }
        for use in tree.importUses {
            switch use.kind {
            case .namespaceMember:
                edits.append((use.offsets, ""))
            case let .renamed(_, original):
                edits.append((use.offsets, original))
            }
        }
        guard !edits.isEmpty else {
            return source
        }
        edits.sort { $0.offsets.lowerBound > $1.offsets.lowerBound }
        var characters = Array(source)
        for edit in edits {
            let range = edit.offsets.clamped(to: 0..<characters.count)
            let original = characters[range]
            let replacement: [Character]
            if let text = edit.replacement {
                replacement = Array(text)
            } else {
                replacement = original.map { $0 == "\n" || $0 == "\r" ? $0 : " " }
            }
            characters.replaceSubrange(range, with: replacement)
        }
        return String(characters)
    }
}

/// Entry point to the shared syntax tree for hosts outside the compiler core.
public enum AdaScriptSyntax {
    /// Parses one source into the tree every consumer shares: declarations with visibility, annotations
    /// with targets, and imports with ranges. The parser tolerates incomplete code, as an editor needs.
    public static func parse(source: String, path: String) -> AdaScriptSyntaxTree {
        AdaScriptSyntaxParser(source: source, path: path).parse().syntax
    }
}

/// A bare identifier in a module body that could name a declaration from another module.
public struct AdaScriptNameReference: Equatable, Hashable, Sendable {
    public var name: String
    public var range: AdaScriptSourceRange

    public init(name: String, range: AdaScriptSourceRange) {
        self.name = name
        self.range = range
    }
}
