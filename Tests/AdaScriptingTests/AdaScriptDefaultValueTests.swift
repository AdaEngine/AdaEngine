import AdaScriptCompilerCore
import Testing

@Suite("AdaScript default value syntax and schema defaults")
struct AdaScriptDefaultValueTests {
    private func defaults(_ source: String) -> [AdaScriptDefaultValue] {
        AdaScriptSyntax.parse(source: source, path: "Main.ada").defaultValues.map(\.value)
    }

    private func fields(_ declarations: String, enumSource: String = "") throws -> [String: AdaScriptSchemaField.Value] {
        let source = "\(enumSource)\n@component(id: \"t\")\nstruct T {\n\(declarations)\n}"
        let schemas = try AdaScriptSchemaParser.parse(sources: [AdaScriptCompilerSource(path: "T.ada", source: source)])
        let fields = try #require(schemas.first?.fields)
        return Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.defaultValue) })
    }

    private func message(_ declarations: String, enumSource: String = "") -> String {
        do {
            _ = try fields(declarations, enumSource: enumSource)
            return ""
        } catch {
            return String(describing: error)
        }
    }

    // MARK: Syntax

    @Test("Every constant shape is recorded without a declared type")
    func syntaxShapes() {
        let source = """
            var a = 1;
            var b = -2.5;
            var c = "hi";
            var d = true;
            var e = null;
            var f = Mode.idle;
            var g = Vector3(1, -2, 3);
            var h = [4, 5];
            """
        #expect(defaults(source) == [
            .number("1"),
            .number("-2.5"),
            .string("hi"),
            .bool(true),
            .name("null"),
            .member(base: "Mode", member: "idle"),
            .construction(callee: "Vector3", components: ["1", "-2", "3"], isClosed: true),
            .construction(callee: nil, components: ["4", "5"], isClosed: true),
        ])
    }

    @Test("Comparisons and member assignments are not declaration defaults")
    func comparisonsAreSkipped() {
        let source = """
            func f(x) { if x == 3 { return 1; } return x <= 2; }
            """
        #expect(defaults(source).isEmpty)
    }

    @Test("Malformed constants keep what was read and report that they are open")
    func malformedConstructions() {
        #expect(defaults("var a = Vector3(1, 2;") == [.construction(callee: "Vector3", components: ["1", "2"], isClosed: false)])
        #expect(defaults("var a = Vector3(1, x);") == [.construction(callee: "Vector3", components: ["1", nil], isClosed: false)])
        #expect(defaults("var a = Vector3(1, 2,);") == [.construction(callee: "Vector3", components: ["1", "2"], isClosed: true)])
        #expect(defaults("var a = Vector3();") == [.construction(callee: "Vector3", components: [], isClosed: true)])
        #expect(defaults("var a = ;") == [.unsupported])
        #expect(defaults("var a =") == [.missing])
        #expect(defaults("var a = -x;") == [.unsupported])
    }

    @Test("The offsets of a constant cover exactly its tokens")
    func offsets() throws {
        let source = "var a = Vector3(1, 2, 3); var b = 4;"
        let found = AdaScriptSyntax.parse(source: source, path: "Main.ada").defaultValues
        let characters = Array(source)

        #expect(found.count == 2)
        #expect(String(characters[try #require(found.first).offsets]) == "Vector3(1, 2, 3)")
        #expect(String(characters[try #require(found.last).offsets]) == "4")
    }

    // MARK: Schema defaults

    @Test("Scalar defaults keep their type")
    func scalarDefaults() throws {
        let values = try fields("""
            @export var count: Int = -3;
            @export var speed: Float = 2.5;
            @export var scale = 1e2;
            @export var title = "a \\"b\\"";
            @export var alive = true;
            """)

        #expect(values["count"] == .int(-3))
        #expect(values["speed"] == .double(2.5))
        #expect(values["scale"] == .double(100))
        #expect(values["title"] == .string("a \"b\""))
        #expect(values["alive"] == .bool(true))
    }

    @Test("Vectors and colors accept calls, lists and constants, with signs and trailing commas")
    func structuredForms() throws {
        let values = try fields("""
            @export var a: Vector2 = [1, -2];
            @export var b: Vector3 = Vector3(0.5, 1, -1,);
            @export var c: Vector4 = Vector4.ZERO;
            @export var d: Color = [0.1, 0.2, 0.3];
            @export var e: Color = Color(0, 0, 0, 0.5);
            @export var f: Color = Color.clear;
            @export var g: Entity = Entity.none;
            @export var h: Asset = null;
            """)

        #expect(values["a"] == .vector([1, -2]))
        #expect(values["b"] == .vector([0.5, 1, -1]))
        #expect(values["c"] == .vector([0, 0, 0, 0]))
        #expect(values["d"] == .color([0.1, 0.2, 0.3, 1]))
        #expect(values["e"] == .color([0, 0, 0, 0.5]))
        #expect(values["f"] == .color([0, 0, 0, 0]))
        #expect(values["g"] == .entity)
        #expect(values["h"] == .asset(path: nil))
    }

    @Test("Errors name the field and what is wrong")
    func errors() {
        #expect(message("@export var a: Vector3 = Vector3(1, x, 3);").contains("Vector3 component of 'a' must be a finite number"))
        #expect(message("@export var a: Vector3 = Vector3(1, 2;").contains("expected ')' in the default of 'a'"))
        #expect(message("@export var a: Vector2 = [1, 2;").contains("expected ']' in the default of 'a'"))
        #expect(message("@export var a: Vector3 = Vector3;").contains("of type Vector3 needs component values"))
        #expect(message("@export var a: Vector3 = Vector2(1, 2, 3);").contains("needs a Vector3(...) or [...] default"))
        #expect(message("@export var a: Vector3 = Vector3.ONE;").contains("only Vector3.ZERO is supported"))
        #expect(message("@export var a: Color = Color(1, 2);").contains("Color default of 'a' needs 3 or 4 components, found 2"))
        #expect(message("@export var a: Color = 3;").contains("needs a Color(...) or [...] default"))
        #expect(message("@export var a = ;").contains("unsupported default for 'a'"))
        #expect(message("@export var a = Foo.bar;").contains("unsupported default for 'a'"))
        #expect(message("@export var a = 99999999999999999999;").contains("invalid integer default for 'a'"))
        #expect(message("@export var a: Int;").contains("field 'a' requires a constant default"))
        #expect(message("@export var a = 1").contains("expected ';' after field 'a'"))
        #expect(message("@export var a: Vector3 = Vector3(1, 2, 3) 4;").contains("expected ';' after field 'a'"))
    }

    @Test("An enum default must name a real case of that enum")
    func enumDefaults() throws {
        let values = try fields("@export var m: Mode = Mode.walking;", enumSource: "enum Mode { idle, walking = 2 }")
        #expect(values["m"] == .enumeration(type: "Mode", cases: ["idle", "walking"], selected: "walking"))

        #expect(message("@export var m: Mode = Other.idle;", enumSource: "enum Mode { idle }").contains("must default to Mode.<case>"))
        #expect(message("@export var m: Mode = Mode;", enumSource: "enum Mode { idle }").contains("must default to Mode.<case>"))
    }

    @Test("Network fields still reject structured values")
    func networkFieldsRejectStructuredValues() {
        let source = """
            @replicated_component(id: "net.body", authority: "host")
            struct NetBody {
                @network_field(1) var position: Vector3 = Vector3(1, 2, 3);
            }
            """
        #expect(throws: (any Error).self) {
            _ = try AdaScriptSchemaParser.parse(sources: [AdaScriptCompilerSource(path: "Net.ada", source: source)])
        }
    }

    @Test("RPC parameters read their defaults from the same syntax")
    func rpcParameterDefaults() throws {
        let source = """
            @network_command(id: "net.move")
            struct Move {
                @network_field(1) var dx: Float = -1.5;
                @network_field(2) var jump: Bool = false;
            }
            """
        let commands = try AdaScriptSchemaParser.parseNetworkCommands(sources: [AdaScriptCompilerSource(path: "Net.ada", source: source)])
        #expect(commands.first?.fields.map(\.defaultValue) == [.double(-1.5), .bool(false)])
    }
}
