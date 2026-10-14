@testable import AdaApp
import AdaECS
import AdaScriptCompilerCore
import AdaScripting
import Testing

@Suite("AdaScript module imports", .serialized)
struct AdaScriptModuleImportTests {
    private func tree(_ source: String) -> AdaScriptSyntaxTree {
        AdaScriptSyntax.parse(source: source, path: "Main.ada")
    }

    @Test("One parser reads selected, renamed, and namespace imports with ranges")
    func parsesImportForms() {
        let syntax = tree("""
            import { Health, Poison as Venom } from "./Combat.ada";
            import * as Shared from "../Shared";
            import {
                Transform
            } from "AdaEngine";
            """)

        #expect(syntax.importDiagnostics.isEmpty)
        #expect(syntax.imports.count == 3)
        guard case let .selected(bindings) = syntax.imports[0].kind else {
            Issue.record("expected a selected import")
            return
        }
        #expect(bindings.map(\.name) == ["Health", "Poison"])
        #expect(bindings.map(\.localName) == ["Health", "Venom"])
        #expect(syntax.imports[0].path == "./Combat.ada")
        #expect(syntax.imports[0].range.start == AdaScriptSourcePosition(line: 0, utf16Column: 0))
        #expect(syntax.imports[1].namespace == "Shared")
        #expect(syntax.imports[2].importedNames == ["Transform"])
        #expect(syntax.imports[2].range.start.line == 2)
        #expect(syntax.imports[2].range.end.line == 4)
    }

    @Test("Malformed imports are reported once each, positioned at the offending token")
    func reportsMalformedImports() {
        let syntax = tree("""
            import Health from "./A";
            import { } from "./B";
            import { A B } from "./C";
            import * Shared from "./D";
            import { E } "./F";
            import { G } from "./H"
            """)

        #expect(syntax.imports.isEmpty)
        #expect(syntax.importDiagnostics.map(\.message) == [
            "expected '{ ... }' or '* as Alias' after import",
            "expected imported identifier before '}'",
            "expected ',' or '}'",
            "expected 'as Alias' after '*' in a namespace import",
            "expected 'from'",
            "expected ';' after import",
        ])
        #expect(syntax.importDiagnostics.map(\.range.start.line) == [0, 1, 2, 3, 4, 5])
    }

    @Test("Declarations carry their visibility")
    func declarationVisibility() {
        let syntax = tree("""
            private func hidden() {}
            public func shown() {}
            func implicit() {}
            private class Secret {}
            private const limit = 3;
            """)
        #expect(syntax.functions.map(\.visibility) == [.private, .public, .public])
        #expect(syntax.types.map(\.visibility) == [.private])
        #expect(syntax.bindings.map(\.visibility) == [.private])
    }

    @Test("Annotation uses record their target and owner")
    func annotationTargets() {
        let syntax = tree("""
            @strict

            @system(id: "s")
            @exclusiveWorld
            class Mover {
                @query(Health) var rows;
                @mystery func update(context) {}
            }
            @component(id: "c") struct Health { @export var current = 1; }
            @oops var loose = 1;
            """)
        let byName = Dictionary(grouping: syntax.annotationUses, by: \.name)

        #expect(byName["strict"]?.first?.target == .module)
        #expect(byName["system"]?.first?.target == .class)
        #expect(byName["system"]?.first?.targetName == "Mover")
        #expect(byName["exclusiveWorld"]?.first?.target == .class)
        #expect(byName["query"]?.first?.target == .property)
        #expect(byName["query"]?.first?.parentName == "Mover")
        #expect(byName["mystery"]?.first?.target == .method)
        #expect(byName["component"]?.first?.target == .struct)
        #expect(byName["export"]?.first?.target == .property)
        #expect(byName["oops"]?.first?.target == .variable)
    }

    @Test("Cycles are reported in full and once, however they are entered")
    func completeCycles() throws {
        let edges = ["A.ada": ["B.ada"], "B.ada": ["C.ada"], "C.ada": ["A.ada"], "D.ada": ["A.ada"], "E.ada": []]
        #expect(AdaScriptModuleOrdering.cycles(edges: edges) == [["A.ada", "B.ada", "C.ada", "A.ada"]])
        #expect(throws: AdaScriptModuleError.importCycle(["A.ada", "B.ada", "C.ada", "A.ada"])) {
            try AdaScriptModuleOrdering.order(roots: ["D.ada"], edges: edges)
        }
        #expect(try AdaScriptModuleOrdering.order(roots: ["E.ada"], edges: edges) == ["E.ada"])
    }

    @Test("Path rules resolve relative, library, and virtual imports the same way for every consumer")
    func pathResolution() throws {
        #expect(try AdaScriptModulePaths.resolveImport("./Combat", from: "Systems/Main.ada") == .source("Systems/Combat.ada"))
        #expect(try AdaScriptModulePaths.resolveImport("../Shared/Steps.ada", from: "Systems/Main.ada") == .source("Shared/Steps.ada"))
        #expect(try AdaScriptModulePaths.resolveImport("@physics.kit/Body", from: "Main.ada") == .source("Libraries/physics.kit/Body.ada"))
        #expect(try AdaScriptModulePaths.resolveImport("AdaUI", from: "Main.ada") == .virtual("AdaUI"))
        #expect(throws: AdaScriptModuleError.self) { try AdaScriptModulePaths.resolveImport("../../Escape", from: "Main.ada") }
        #expect(throws: AdaScriptModuleError.self) { try AdaScriptModulePaths.resolveImport("/etc/passwd", from: "Main.ada") }
        #expect(throws: AdaScriptModuleError.self) { try AdaScriptModulePaths.resolveImport("Combat", from: "Main.ada") }
    }

    @Test("Selected imports enforce public visibility and existing names")
    func visibilityIsEnforced() throws {
        func diagnostics(_ importing: String) throws -> [String] {
            let graph = try AdaScriptModuleGraph(sources: [
                AdaScriptCompilerSource(path: "Main.ada", source: importing),
                AdaScriptCompilerSource(path: "Combat.ada", source: "private func secret() {}\nfunc open() {}\nclass Fighter {}"),
            ])
            return graph.semanticDiagnostics().map(\.message)
        }
        #expect(try diagnostics("import { open, Fighter } from \"./Combat\";").isEmpty)
        #expect(try diagnostics("import { secret } from \"./Combat\";") == ["'secret' is private to './Combat' and cannot be imported"])
        #expect(try diagnostics("import { missing } from \"./Combat\";") == ["'./Combat' does not export 'missing'"])
        let clash = try diagnostics("import { open } from \"./Combat\";\nfunc open() {}")
        #expect(clash.contains("'open' is already declared or imported in this module; rename it or import it with 'as'"))
        #expect(try diagnostics("import { Button, Wheel } from \"AdaUI\";") == ["'AdaUI' does not export 'Wheel'"])
        #expect(try diagnostics("import { AnyComponent } from \"AdaEngine\";").isEmpty)
    }

    @Test("A namespace import runs qualified members and a renamed import runs under its new name")
    @MainActor
    func namespaceAndRenamedImports() async throws {
        let plugin = try AdaScriptPlugin(
            sources: [
                AdaScriptSource(path: "Shared/Math.ada", source: "func triple(value) { return value * 3; }\nfunc offset() { return 4; }"),
                AdaScriptSource(path: "Main.ada", source: """
                    import * as Maths from "./Shared/Math";
                    import { offset as shift } from "./Shared/Math";

                    var observed = 0;

                    @system(id: "namespace.system")
                    class NamespaceSystem {
                        func update(context) { observed = Maths.triple(5) + shift(); }
                    }
                    """),
            ],
            name: "NamespaceImports"
        )
        let world = World(name: "Namespace imports")
        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(plugin.diagnostics.isEmpty)
    }

    @Test("Private members and unknown exports are rejected through a namespace")
    func namespaceMemberVisibility() {
        func message(_ member: String) -> String {
            do {
                _ = try AdaScriptPlugin(
                    sources: [
                        AdaScriptSource(path: "Shared.ada", source: "private func hidden() {}\nfunc shown() {}"),
                        AdaScriptSource(path: "Main.ada", source: """
                            import * as Shared from "./Shared";
                            @system(id: "s")
                            class S { func update(context) { Shared.\(member)(); } }
                            """),
                    ],
                    name: "NamespaceVisibility"
                )
                return ""
            } catch {
                return String(describing: error)
            }
        }
        #expect(message("shown").isEmpty)
        #expect(message("hidden").contains("'hidden' is private to 'Shared.ada'"))
        #expect(message("absent").contains("'Shared.ada' does not export 'absent'"))
    }

    @Test("A name declared by two modules is reported with both files")
    func duplicateDeclarations() throws {
        let graph = try AdaScriptModuleGraph(sources: [
            AdaScriptCompilerSource(path: "A.ada", source: "func helper() {}"),
            AdaScriptCompilerSource(path: "B.ada", source: "func helper() {}"),
        ])
        let messages = graph.semanticDiagnostics().map(\.message)
        #expect(messages.count == 2)
        #expect(messages.allSatisfy { $0.contains("A.ada, B.ada") })
    }

    @Test("A syntax error in an imported file is reported instead of a missing export")
    func syntaxErrorWinsOverMissingExport() {
        #expect {
            try AdaScriptPlugin(
                sources: [
                    AdaScriptSource(path: "Main.ada", source: "import { broken } from \"./Broken\";\n@system(id: \"s\") class S { func update(context) {} }"),
                    AdaScriptSource(path: "Broken.ada", source: "func broken( {"),
                ],
                name: "BrokenImport"
            )
        } throws: { error in
            guard case let .compilation(lines)? = error as? AdaScriptError else { return false }
            return lines.contains { $0.hasPrefix("Broken.ada:") }
        }
    }
}
