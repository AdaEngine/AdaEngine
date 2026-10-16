import AdaScriptCompilerCore
import Testing

@Suite("AdaScript outline")
struct AdaScriptOutlineTests {
    private func outline(_ source: String) -> AdaScriptOutline {
        AdaScriptSyntax.parse(source: source, path: "Main.ada").outline
    }

    private static let sample = """
        enum Mode { idle }
        var counter = 0;
        const LIMIT = 10;

        @component(id: "game.health")
        struct Health {
            var current = 4;
            static var shared = 3;
            const cap = 5;
        }

        @system(id: "combat")
        @access(read: [Health])
        class Combat {
            private var secret = "}";
            async func fetch(context) { var inner = 1; if (inner > 0) { inner = 2; } }
            func update(context) {}
        }

        func helper(a) { return a; }
        async func later() {}
        """

    @Test("Types list their direct members in source order with kinds")
    func types() throws {
        let found = outline(Self.sample)

        #expect(found.types.map(\.symbol.name) == ["Mode", "Health", "Combat"])
        #expect(found.types.map(\.symbol.kind) == [.enum, .struct, .class])
        let health = try #require(found.types.first { $0.symbol.name == "Health" })
        #expect(health.symbol.members.map(\.name) == ["current", "shared", "cap"])
        #expect(health.symbol.members.map(\.kind) == [.property, .property, .property])
        #expect(health.symbol.members.map(\.isStatic) == [false, true, false])
        let combat = try #require(found.types.last)
        #expect(combat.symbol.members.map(\.name) == ["secret", "fetch", "update"])
        #expect(combat.symbol.members.map(\.kind) == [.property, .method, .method])
        #expect(combat.symbol.members.map(\.isAsync) == [false, true, false])
    }

    @Test("Locals inside a body are not members, and braces in strings do not end a body")
    func bodiesAreSkipped() throws {
        let combat = try #require(outline(Self.sample).types.last)

        #expect(combat.isTerminated)
        #expect(combat.symbol.members.map(\.name).contains("inner") == false)
    }

    @Test("Globals exclude everything inside a type")
    func globals() {
        let found = outline(Self.sample)

        #expect(found.globals.map(\.name) == ["counter", "LIMIT", "helper", "later"])
        #expect(found.globals.map(\.kind) == [.variable, .constant, .function, .function])
        #expect(found.globals.map(\.isAsync) == [false, false, false, true])
    }

    @Test("Annotations before a type are attached, with their values")
    func annotations() throws {
        let combat = try #require(outline(Self.sample).types.last)

        #expect(combat.annotations.map(\.name) == ["system", "access"])
        #expect(combat.annotations.last?.value(labelled: "read") == .list([.identifier("Health")]))
        #expect(outline(Self.sample).types.first?.annotations.isEmpty == true)
    }

    @Test("A type that never closes runs to the end of the file")
    func unterminatedType() throws {
        let found = outline("class A { var a = 1; func f() { ")
        let type = try #require(found.types.first)

        #expect(!type.isTerminated)
        #expect(type.symbol.members.map(\.name) == ["a", "f"])
        #expect(type.bodyStart.utf16Column == 8)
        #expect(type.bodyEnd.utf16Column == 30)
    }

    @Test("A declaration needs only its keyword and a name")
    func unfinishedDeclarations() throws {
        let found = outline("class A { func fo var x const ")
        let members = try #require(found.types.first).symbol.members

        #expect(members.map(\.name) == ["fo", "x"])
        #expect(members.map(\.kind) == [.method, .property])
    }

    @Test("Type ranges run from the keyword to the closing brace; members use their name")
    func ranges() throws {
        let source = "class A {\n    var a = 1;\n}"
        let type = try #require(outline(source).types.first)

        #expect(type.symbol.range.start == AdaScriptSourcePosition(line: 0, utf16Column: 0))
        #expect(type.symbol.range.end == AdaScriptSourcePosition(line: 2, utf16Column: 1))
        #expect(type.symbol.selectionRange.start == AdaScriptSourcePosition(line: 0, utf16Column: 6))
        let member = try #require(type.symbol.members.first)
        #expect(member.range.start == AdaScriptSourcePosition(line: 1, utf16Column: 8))
        #expect(member.range.end == AdaScriptSourcePosition(line: 1, utf16Column: 9))
        #expect(type.bodyEnd == AdaScriptSourcePosition(line: 2, utf16Column: 0))
    }

    @Test("Nested types are not separate entries")
    func nestedTypes() {
        let found = outline("class A { class Inner { var x = 1; } var y = 2; }")

        #expect(found.types.map(\.symbol.name) == ["A"])
        #expect(found.types.first?.symbol.members.map(\.name) == ["y"])
    }

    @Test("Keywords in comments and strings are not declarations")
    func commentsAndStrings() {
        let found = outline("""
            // class Fake { var no = 1; }
            /* func hidden() {} */
            var s = "class Fake { }";
            class Real { var yes = 1; }
            """)

        #expect(found.types.map(\.symbol.name) == ["Real"])
        #expect(found.globals.map(\.name) == ["s"])
    }

    @Test("An empty file has an empty outline")
    func empty() {
        #expect(outline("") == AdaScriptOutline())
        #expect(outline("   \n  ") == AdaScriptOutline())
    }
}
