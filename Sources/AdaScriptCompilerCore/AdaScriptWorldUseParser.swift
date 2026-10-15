/// One `context.world` or `context.world.<member>` in code, for capability inference and diagnostics.
public struct AdaScriptWorldUse: Equatable, Hashable, Sendable {
    /// The second argument of a call, which names the component for `read`, `write` and `has`.
    public struct Argument: Equatable, Hashable, Sendable {
        public var isString: Bool
        public var range: AdaScriptSourceRange
        /// The token text; a string without its quotes.
        public var text: String

        public init(isString: Bool, range: AdaScriptSourceRange, text: String) {
            self.isString = isString
            self.range = range
            self.text = text
        }
    }

    /// `name = context.world`: the place that would keep the world beyond the callback.
    public struct Assignment: Equatable, Hashable, Sendable {
        public enum Qualifier: Equatable, Hashable, Sendable {
            /// `var name = ...` or `const name = ...`, a local that does not outlive the callback.
            case declaration
            /// `name = ...`
            case bare
            /// `self.name = ...`
            case selfMember
            /// `other.name = ...`
            case otherMember
        }

        public var name: String
        public var nameRange: AdaScriptSourceRange
        public var qualifier: Qualifier

        public init(name: String, nameRange: AdaScriptSourceRange, qualifier: Qualifier) {
            self.name = name
            self.nameRange = nameRange
            self.qualifier = qualifier
        }
    }

    public var assignment: Assignment?
    /// The member after `context.world.`, or `nil` for the bare world.
    public var member: String?
    public var memberRange: AdaScriptSourceRange?
    public var offsets: Range<Int>
    public var range: AdaScriptSourceRange
    public var secondArgument: Argument?

    public init(
        assignment: Assignment? = nil,
        member: String? = nil,
        memberRange: AdaScriptSourceRange? = nil,
        offsets: Range<Int>,
        range: AdaScriptSourceRange,
        secondArgument: Argument? = nil
    ) {
        self.assignment = assignment
        self.member = member
        self.memberRange = memberRange
        self.offsets = offsets
        self.range = range
        self.secondArgument = secondArgument
    }
}

/// Finds every `context.world` use in a token stream.
struct AdaScriptWorldUseParser {
    private let tokens: [AdaScriptAnalysisToken]

    init(tokens: [AdaScriptAnalysisToken]) {
        self.tokens = tokens
    }

    func parseAll() -> [AdaScriptWorldUse] {
        tokens.indices.compactMap { index in
            guard index + 2 < tokens.count, tokens[index].text == "context", tokens[index + 1].text == ".", tokens[index + 2].text == "world" else {
                return nil
            }
            return use(at: index)
        }
    }

    private func use(at index: Int) -> AdaScriptWorldUse {
        let worldIndex = index + 2
        var last = worldIndex
        var member: String?
        var memberRange: AdaScriptSourceRange?
        if worldIndex + 2 < tokens.count, tokens[worldIndex + 1].text == ".", tokens[worldIndex + 2].kind == .identifier {
            last = worldIndex + 2
            member = tokens[last].text
            memberRange = tokens[last].range
        }
        return AdaScriptWorldUse(
            assignment: assignment(before: index),
            member: member,
            memberRange: memberRange,
            offsets: tokens[index].startOffset..<tokens[last].endOffset,
            range: AdaScriptSourceRange(start: tokens[index].range.start, end: tokens[last].range.end),
            secondArgument: member == nil ? nil : secondArgument(afterMemberAt: last)
        )
    }

    private func assignment(before index: Int) -> AdaScriptWorldUse.Assignment? {
        guard index >= 2, tokens[index - 1].text == "=", tokens[index - 2].kind == .identifier else {
            return nil
        }
        let name = tokens[index - 2]
        let qualifier: AdaScriptWorldUse.Assignment.Qualifier
        if index >= 3, ["var", "const"].contains(tokens[index - 3].text) {
            qualifier = .declaration
        } else if index >= 4, tokens[index - 3].text == ".", tokens[index - 4].text == "self" {
            qualifier = .selfMember
        } else if index >= 3, tokens[index - 3].text == "." {
            qualifier = .otherMember
        } else {
            qualifier = .bare
        }
        return AdaScriptWorldUse.Assignment(name: name.text, nameRange: name.range, qualifier: qualifier)
    }

    /// The token after the first top-level comma of the call whose callee is at `memberIndex`.
    private func secondArgument(afterMemberAt memberIndex: Int) -> AdaScriptWorldUse.Argument? {
        let open = memberIndex + 1
        guard open < tokens.count, tokens[open].text == "(" else {
            return nil
        }
        var depth = 0
        for index in open..<tokens.count {
            switch tokens[index].text {
            case "(", "[":
                depth += 1
            case ")", "]":
                depth -= 1
                if depth == 0 { return nil }
            case "," where depth == 1:
                guard index + 1 < tokens.count else { return nil }
                let token = tokens[index + 1]
                let isString = token.kind == .string
                return AdaScriptWorldUse.Argument(
                    isString: isString,
                    range: token.range,
                    text: isString ? AdaScriptAnnotationValueParser.unquoted(token.text) : token.text
                )
            default:
                break
            }
        }
        return nil
    }
}
