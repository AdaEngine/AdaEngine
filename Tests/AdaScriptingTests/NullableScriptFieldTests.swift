import AdaApp
import AdaECS
@testable import AdaScripting
import Foundation
import GravityAOT
import Math
import Testing

@Component
struct NullableScriptProbe {
    var destination: Vector3?
    @AdaScriptInit
    init(destination: Vector3? = [1, 2, 3]) { self.destination = destination }
}

@Component
struct ScriptUtf8Probe {
    var text: String = ""
}

@MainActor
@Suite("Nullable AdaScript host fields", .serialized)
struct NullableScriptFieldTests {
    @Test("Real VM compilation preserves Cyrillic and imported CRLF source")
    func utf8AndWindowsLines() async throws {
        ScriptUtf8Probe.registerComponent()
        let source = """
            import { greeting } from "./Greeting";
            @system class Hello {
                @query(ScriptUtf8Probe) var rows;
                var prefix = "Робот: ";
                func update(context) {
                    for (var row in rows) { row.scriptUtf8Probe.text = prefix + greeting(); }
                }
            }
            """
        let helper = "func greeting() { return \"пришёл к цели\"; }\r\n"
        let script = try AdaScriptPlugin(sources: [
            .init(path: "Main.ada", source: source.replacingOccurrences(of: "\n", with: "\r\n")),
            .init(path: "Greeting.ada", source: helper),
        ], name: "Utf8Navigation")
        let app = AppWorlds(main: World())
        let entity = app.main.spawn { ScriptUtf8Probe() }
        script.setup(in: app)
        await app.main.runScheduler(.update)
        #expect(entity.components[ScriptUtf8Probe.self]?.text == "Робот: пришёл к цели")
        #expect(script.diagnostics.isEmpty)
    }

    private func register() {
        RuntimeTypeRegistry.registerComponent(NullableScriptProbe.self, names: ["NullableScriptProbe"], makeDefault: { NullableScriptProbe() })
    }

    @Test("VM constructors distinguish omitted arguments, explicit null and a vector")
    func vmConstructors() async throws {
        register()
        let script = try AdaScriptPlugin(source: """
            @system(id: "nullable.construct") class Construct {
                var done = false;
                func update(context) {
                    if (!done) {
                        context.world.spawn([NullableScriptProbe()]);
                        context.world.spawn([NullableScriptProbe(destination: null)]);
                        context.world.spawn([NullableScriptProbe(destination: [4.0, 5.0, 6.0])]);
                        done = true;
                    }
                }
            }
            """, name: "NullableConstructors")
        let app = AppWorlds(main: World())
        script.setup(in: app)
        await app.main.runScheduler(.update)
        app.main.flush()
        let values = app.main.getEntities().compactMap { $0.components[NullableScriptProbe.self] }
        #expect(values.count == 3)
        #expect(values.filter { $0.destination == nil }.count == 1)
        #expect(values.contains { $0.destination == [1, 2, 3] })
        #expect(values.contains { $0.destination == [4, 5, 6] })
        #expect(script.diagnostics.isEmpty)
    }

    @Test("Native host construction preserves omitted defaults and explicit null")
    func nativeConstructors() throws {
        register()
        let factory = NativeComponentFactory(scope: NativeCallbackScope(), components: [])
        func construct(_ presence: [NativeValue]) throws -> NullableScriptProbe? {
            let result = try factory.call("makeNamed", arguments: [.string("NullableScriptProbe"), .list([.null]), .list(presence)])
            guard case let .host(host)? = result, let draft = host as? NativeComponentDraft else { return nil }
            return try draft.take() as? NullableScriptProbe
        }
        let defaultValue = try construct([])
        let nullValue = try construct([.integer(0)])
        let omitted = try #require(defaultValue)
        let cleared = try #require(nullValue)
        #expect(omitted.destination == [1, 2, 3])
        #expect(cleared.destination == nil)
    }
}
