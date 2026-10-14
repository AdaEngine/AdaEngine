/// Static rules for `@test` functions (ADR-0024): what a test may look like, and which names only tests may use.
public enum AdaScriptTestSupport {
    /// The test-only API. Production code that references one of these, without declaring its own, cannot ship.
    public static let reservedNames: Set<String> = [
        "TestWorld", "expect", "expectEqual", "expectNear", "expectNil", "fail", "require",
    ]

    /// Problems with the shape of each `@test` function, formatted `path:line:column: message`.
    public static func problems(in tree: AdaScriptSyntaxTree) -> [String] {
        tree.tests.compactMap { test in
            guard test.parameterCount == 0 else {
                return location(of: test.annotationRange, in: tree.path)
                    + "@test function '\(test.name)' cannot take parameters; create a TestWorld inside the test"
            }
            return nil
        }
    }

    /// References to test-only names in source that has already had its `@test` functions removed.
    ///
    /// - Parameters:
    ///   - source: The module file after stripping.
    ///   - testNames: Every `@test` function name in the module.
    ///   - declared: Every name the module declares itself, so a project's own `fail` is not mistaken for the test API.
    public static func leaks(inStripped source: String, path: String, testNames: Set<String>, declared: Set<String>) -> [String] {
        let forbidden = testNames.union(reservedNames.subtracting(declared))
        guard !forbidden.isEmpty else {
            return []
        }
        return AdaScriptSyntax.parse(source: source, path: path).references
            .filter { forbidden.contains($0.name) }
            .map { location(of: $0.range, in: path) + "'\($0.name)' is test-only and cannot be used outside @test functions" }
    }

    private static func location(of range: AdaScriptSourceRange, in path: String) -> String {
        "\(path):\(range.start.line + 1):\(range.start.utf16Column + 1): "
    }
}
