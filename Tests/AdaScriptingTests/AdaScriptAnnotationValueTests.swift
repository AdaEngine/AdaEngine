import AdaScriptCompilerCore
import Testing

@Suite("AdaScript annotation values")
struct AdaScriptAnnotationValueTests {
    private func annotations(_ source: String) -> [AdaScriptAnnotationSyntax] {
        AdaScriptSyntax.parse(source: source, path: "Main.ada").annotations
    }

    @Test("Labelled and positional literals keep their kinds and order")
    func literalKinds() throws {
        let tree = annotations(#"@component(id: "game.health", version: 2, replicated: true, aliases: ["Hp", "Life"]) struct Health {}"#)
        let annotation = try #require(tree.first)

        #expect(annotation.name == "component")
        #expect(annotation.problem == nil)
        #expect(annotation.value(labelled: "id") == .string("game.health"))
        #expect(annotation.value(labelled: "version") == .number("2"))
        #expect(annotation.value(labelled: "replicated") == .bool(true))
        #expect(annotation.value(labelled: "aliases") == .list([.string("Hp"), .string("Life")]))
        #expect(annotation.values.map(\.label) == ["id", "version", "replicated", "aliases"])
    }

    @Test("Qualified component references keep their alias")
    func qualifiedReferences() throws {
        let annotation = try #require(annotations("@query(Game.Health as health, optional: [Game.Armor]) var q;").first)

        #expect(annotation.positionalValues == [.identifier("Game.Health as health")])
        #expect(annotation.value(labelled: "optional") == .list([.identifier("Game.Armor")]))
    }

    @Test("String escapes are resolved and quotes removed")
    func stringEscapes() throws {
        let annotation = try #require(annotations(#"@test("say \"hi\"") func a() {}"#).first)

        #expect(annotation.positionalValues == [.string(#"say "hi""#)])
    }

    @Test("Malformed argument lists report a problem and keep earlier values")
    func problems() throws {
        let unterminatedList = try #require(annotations(#"@component(id: "a", aliases: ["x", "y") struct A {}"#).first)
        let unsupported = try #require(annotations("@component(id: -1) struct A {}").first)
        let unclosed = try #require(annotations(#"@component(id: "a" struct A {}"#).first)

        #expect(unterminatedList.problem == "unterminated list for @component aliases")
        #expect(unterminatedList.value(labelled: "id") == .string("a"))
        #expect(unsupported.problem == "unsupported value for @component id")
        #expect(unclosed.problem == "unterminated @component annotation")
    }

    @Test("Every annotation is reported with source offsets, attached or not")
    func offsets() throws {
        let source = "@strict\n@system(id: \"a\")\nclass A {}"
        let found = annotations(source)

        #expect(found.map(\.name) == ["strict", "system"])
        let system = try #require(found.last)
        let characters = Array(source)
        #expect(String(characters[system.offsets]) == #"@system(id: "a")"#)
    }

    @Test("Enums report their cases in order, ignoring raw values, including nested declarations")
    func enumCases() {
        let source = """
            enum Mode { idle, walking = 2, running }
            class Holder {
                enum Inner { a, a }
            }
            """
        let enums = AdaScriptSyntax.parse(source: source, path: "Main.ada").enums

        #expect(enums.map(\.name) == ["Mode", "Inner"])
        #expect(enums.first?.cases == ["idle", "walking", "running"])
        #expect(enums.last?.cases == ["a", "a"])
    }
}
