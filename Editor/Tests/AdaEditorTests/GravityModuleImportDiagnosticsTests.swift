import Foundation
import GravityLanguageCore
import Testing

@Suite("AdaScript module imports in the language server")
struct GravityModuleImportDiagnosticsTests {
    private func makeProject(_ files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AdaScriptModules-\(UUID().uuidString)", isDirectory: true)
        for (path, text) in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return root
    }

    private func diagnostics(in root: URL, file: String) throws -> [String] {
        let workspace = GravityWorkspace()
        workspace.configure(rootURIs: [root.absoluteString])
        return try #require(workspace.analysis(for: root.appendingPathComponent(file).absoluteString)?.diagnostics.map(\.message))
    }

    @Test("Selected imports are checked for existence and public visibility")
    func visibility() throws {
        let root = try makeProject([
            "Combat.ada": "private func secret() {}\nfunc open() {}\nclass Fighter {}",
            "Good.ada": "import { open, Fighter } from \"./Combat\";",
            "Private.ada": "import { secret } from \"./Combat\";",
            "Missing.ada": "import { nothing } from \"./Combat\";",
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(try diagnostics(in: root, file: "Good.ada").isEmpty)
        #expect(try diagnostics(in: root, file: "Private.ada") == ["'secret' is private to './Combat' and cannot be imported"])
        #expect(try diagnostics(in: root, file: "Missing.ada") == ["'./Combat' does not export 'nothing'"])
    }

    @Test("Namespace and renamed imports are understood")
    func namespaceImports() throws {
        let root = try makeProject([
            "Shared.ada": "private func hidden() {}\nfunc shown() {}",
            "Main.ada": """
                import * as Shared from "./Shared";
                import { shown as display } from "./Shared";
                var a = Shared.shown();
                var b = display();
                var c = Shared.hidden();
                var d = Shared.absent();
                """,
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let found = try diagnostics(in: root, file: "Main.ada")
        #expect(found.contains("'hidden' is private to 'Shared.ada'"))
        #expect(found.contains("'Shared.ada' does not export 'absent'"))
        #expect(!found.contains { $0.contains("shown") || $0.contains("Namespace imports") || $0.contains("Unknown value") })

        let workspace = GravityWorkspace()
        workspace.configure(rootURIs: [root.absoluteString])
        let imports = try #require(workspace.analysis(for: root.appendingPathComponent("Main.ada").absoluteString)?.imports)
        #expect(imports.first?.namespace == "Shared")
        #expect(imports.last?.aliases == ["display": "shown"])
        #expect(imports.last?.localNames == ["display"])
    }

    @Test("Import cycles are reported in full on every import that closes them")
    func cycles() throws {
        let root = try makeProject([
            "A.ada": "import { b } from \"./B\";\nfunc a() {}",
            "B.ada": "import { c } from \"./C\";\nfunc b() {}",
            "C.ada": "import { a } from \"./A\";\nfunc c() {}",
            "Clean.ada": "func clean() {}",
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        for file in ["A.ada", "B.ada", "C.ada"] {
            #expect(try diagnostics(in: root, file: file).contains("Import cycle: A.ada -> B.ada -> C.ada -> A.ada"))
        }
        #expect(try diagnostics(in: root, file: "Clean.ada").isEmpty)
    }

    @Test("A name declared by an imported module and the importer is reported, unrelated files are not")
    func duplicates() throws {
        let root = try makeProject([
            "Shared.ada": "func helper() {}",
            "Main.ada": "import { helper } from \"./Shared\";\nfunc helper() {}",
            "Unrelated.ada": "func helper() {}",
            "Alone.ada": "func helper() {}",
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let main = try diagnostics(in: root, file: "Main.ada")
        #expect(main.contains { $0.contains("'helper' is declared in more than one module") })
        #expect(try diagnostics(in: root, file: "Alone.ada").isEmpty)
    }

    @Test("Imports resolve from the configured source root and reject escaping it")
    func sourceRoot() throws {
        let root = try makeProject([
            ".ada/project.json": #"{"paths": {"sources": "Sources"}}"#,
            "Sources/Main.ada": "import { shared } from \"./Shared\";\nimport { secret } from \"../Secret\";",
            "Sources/Shared.ada": "func shared() {}",
            "Secret.ada": "func secret() {}",
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        let found = try diagnostics(in: root, file: "Sources/Main.ada")
        #expect(found == ["Import escapes the configured AdaScript workspace"])
    }

    @Test("Library imports resolve to restored library sources")
    func libraryImports() throws {
        let root = try makeProject([
            "Sources/Main.ada": "import { Body } from \"@physics.kit/Body\";",
            ".ada/libraries/physics.kit-1.0.0/Body.ada": "class Body {}",
        ])
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(try diagnostics(in: root, file: "Sources/Main.ada").isEmpty)
    }

    @Test("Unknown annotations and misplaced annotations are diagnosed with their position")
    func annotationDiagnostics() {
        let source = """
            @mystery
            class Thing {
                @query(Health) var rows;
                @system func update(context) {}
                @events(Damage) @eventWriter(Heal) var both;
            }
            @res var global = 1;
            """
        let found = GravityLanguageService().analyze(text: source).diagnostics
        let byLine = Dictionary(grouping: found, by: \.range.start.line).mapValues { $0.map(\.message) }

        #expect(byLine[0] == ["Unknown annotation @mystery"])
        #expect(byLine[3]?.contains("@system cannot annotate a method; it applies to a class") == true)
        #expect(byLine[6]?.contains("@res cannot annotate a top-level variable; it applies to a stored property") == true)
        #expect(byLine[2] == nil)
    }

    @Test("Completion inside an import list offers a module's public names")
    func importNameCompletion() throws {
        let root = try makeProject([
            "Combat.ada": "private func secret() {}\nfunc strike() {}\nclass Fighter {}",
            "Main.ada": "import { } from \"./Combat\";",
            "UI.ada": "import { Te } from \"AdaUI\";",
            "Engine.ada": "import { In } from \"AdaEngine\";",
        ])
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = GravityWorkspace()
        workspace.configure(rootURIs: [root.absoluteString])
        func labels(_ file: String, column: Int) -> [String] {
            workspace.completions(uri: root.appendingPathComponent(file).absoluteString, position: GravitySourcePosition(line: 0, utf16Column: column)).map(\.label)
        }

        let combat = labels("Main.ada", column: 9)
        #expect(combat.contains("strike") && combat.contains("Fighter"))
        #expect(!combat.contains("secret"))
        #expect(labels("UI.ada", column: 11) == ["Text"])
        #expect(labels("Engine.ada", column: 11) == ["Input"])
    }
}
