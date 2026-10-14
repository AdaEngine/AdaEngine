@testable import AdaApp
import AdaECS
import AdaScriptCompilerCore
@testable import AdaScripting
import Testing

@Suite("AdaScript annotation diagnostics", .serialized)
struct AdaScriptAnnotationDiagnosticsTests {
    private func compile(_ sources: [AdaScriptSource]) -> String {
        do {
            _ = try AdaScriptPlugin(sources: sources, name: "AnnotationDiagnostics")
            return ""
        } catch {
            return String(describing: error)
        }
    }

    @Test("Unknown annotations are rejected with their file, line and column")
    func unknownAnnotation() {
        let message = compile([
            AdaScriptSource(path: "Systems/Move.ada", source: """
                @system(id: "move")
                class Move {
                    @mystery var speed = 1;
                    func update(context) {}
                }
                """),
        ])
        #expect(message.contains("Systems/Move.ada:3:5: Unknown annotation @mystery"))
    }

    @Test("Annotations on an unsupported target name what they can annotate")
    func unsupportedTarget() {
        let message = compile([
            AdaScriptSource(path: "Main.ada", source: """
                @system(id: "s")
                class S {
                    @exclusiveWorld var flag = 1;
                    func update(context) {}
                }
                @query(Health) func helper() {}
                """),
        ])
        #expect(message.contains("Main.ada:3:5: @exclusiveWorld cannot annotate a stored property; it applies to a class"))
        #expect(message.contains("Main.ada:6:1: @query cannot annotate a function; it applies to a stored property"))
    }

    @Test("Every annotation the repository's AdaScript uses is in the catalog")
    func catalogCoversKnownAnnotations() {
        for name in [
            "system", "query", "res", "after", "before", "access", "exclusiveWorld", "events", "eventWriter", "component", "resource",
            "replicated_component", "network_command", "network_field", "local", "rpc", "remote_commands", "scriptable", "export",
            "tool", "view", "previewable", "state", "environment", "strict", "nonsendable", "binding",
        ] {
            #expect(AdaScriptAnnotationCatalog.rules[name] != nil, "@\(name)")
        }
    }

    @Test("Annotation misuse inside a system carries the file and position of the annotation")
    func locatedManifestErrors() {
        let message = compile([
            AdaScriptSource(path: "Combat/Orphan.ada", source: """
                class NotASystem {
                    @events(Damage) var hits;
                }
                @system(id: "ok")
                class Ok { func update(context) {} }
                """),
        ])
        #expect(message.contains("Combat/Orphan.ada:2:5: @events must annotate a stored property inside an @system class"))
    }

    @Test("A system plan is identified by its file and class")
    func qualifiedIdentity() throws {
        let plugin = try AdaScriptPlugin(
            sources: [
                AdaScriptSource(path: "Systems/Move.ada", source: "@system(id: \"move\")\nclass MoveSystem { func update(context) {} }"),
                AdaScriptSource(path: "Systems/Fade.ada", source: "@system(id: \"fade\")\nclass FadeSystem { func update(context) {} }"),
            ],
            name: "QualifiedIdentity"
        )
        let plans = Dictionary(uniqueKeysWithValues: plugin.plans.map { ($0.identifier, $0) })

        #expect(plans["move"]?.qualifiedIdentity == "Systems/Move.ada#MoveSystem")
        #expect(plans["fade"]?.qualifiedIdentity == "Systems/Fade.ada#FadeSystem")
        #expect(plans["move"]?.source.line == 1)
    }
}
