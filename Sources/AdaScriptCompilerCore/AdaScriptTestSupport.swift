/// Static rules for `@test` functions (ADR-0024): what a test may look like, and which names only tests may use.
public enum AdaScriptTestSupport {
    /// The test-only API. Production code that references one of these, without declaring its own, cannot ship.
    public static let reservedNames: Set<String> = [
        "TestWorld", "expect", "expectEqual", "expectNear", "expectNil", "fail", "require",
    ]

    /// Whether a canonical source path belongs to the project's `Tests/` root: integration tests that exist
    /// only in the test configuration and see public declarations only.
    public static func isTestSource(_ path: String) -> Bool {
        path == "Tests" || path.hasPrefix("Tests/")
    }

    /// Imports that gameplay code writes into the `Tests/` root, formatted `path:line:column: message`.
    public static func testImportProblems(in tree: AdaScriptSyntaxTree) -> [String] {
        guard !isTestSource(tree.path) else {
            return []
        }
        return tree.imports.compactMap { declaration in
            guard case let .source(target)? = try? AdaScriptModulePaths.resolveImport(declaration.path, from: tree.path), isTestSource(target) else {
                return nil
            }
            return location(of: declaration.pathRange, in: tree.path) + "gameplay code cannot import from the Tests/ root"
        }
    }

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
