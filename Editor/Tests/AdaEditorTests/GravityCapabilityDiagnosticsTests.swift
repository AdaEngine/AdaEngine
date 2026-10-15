import GravityLanguageCore
import Testing

@Suite("AdaScript world capability diagnostics")
struct GravityCapabilityDiagnosticsTests {
    private func messages(_ source: String) -> [String] {
        GravityLanguageService().analyze(text: source).diagnostics.map(\.message)
    }

    @Test("A well declared exclusive and access system is clean")
    func acceptsDeclaredCapabilities() {
        let source = """
            @system(id: "ok")
            @exclusiveWorld
            @access(read: [Health], write: [Poison])
            class Ok {
                @events(Damage) var hits;
                @eventWriter(Heal) var heal;
                func update(context) {
                    context.world.spawnImmediate([]);
                    context.world.read(1, "Health", "current");
                    context.world.write(1, "Poison", "duration", 2);
                    var world = context.world;
                }
            }
            """
        #expect(messages(source).isEmpty)
    }

    @Test("Immediate operations require @exclusiveWorld")
    func immediateRequiresExclusive() {
        let source = """
            @system(id: "plain")
            class Plain {
                func update(context) { context.world.despawnImmediate(1); }
            }
            """
        #expect(messages(source) == ["world.despawnImmediate requires @exclusiveWorld on the system"])
    }

    @Test("Dynamic access requires @access and honors the declared sets")
    func dynamicAccessIsChecked() {
        let undeclared = """
            @system(id: "none")
            class None { func update(context) { context.world.read(1, "Health", "current"); } }
            """
        #expect(messages(undeclared) == ["world.read requires an explicit @access declaration on the system"])

        let declared = """
            @system(id: "set")
            @access(read: [Health], write: [Poison])
            class Set {
                func update(context) {
                    context.world.write(1, "Health", "current", 1);
                    context.world.read(1, "Mana", "current");
                    context.world.write(1, "Mana", "current", 1);
                }
            }
            """
        #expect(messages(declared) == [
            "'Health' is declared read-only in @access",
            "'Mana' is not declared in @access",
            "'Mana' is not declared in @access(write:)",
        ])
    }

    @Test("A qualified or quoted @access name covers the short component name")
    func accessAcceptsQualifiedAndQuotedNames() {
        let source = """
            @system(id: "qualified")
            @access(read: [Game.Health], write: ["Poison"])
            class Qualified {
                func update(context) {
                    context.world.read(1, "Health", "current");
                    context.world.write(1, "Poison", "duration", 2);
                }
            }
            """
        #expect(messages(source).isEmpty)
    }

    @Test("Storing context.world in a property or global is a lifetime violation")
    func retainedCapabilityIsFlagged() {
        let source = """
            var saved = null;
            @system(id: "leak")
            class Leak {
                var kept = null;
                func update(context) {
                    saved = context.world;
                    kept = context.world;
                    self.kept = context.world;
                    var local = context.world;
                }
            }
            """
        let found = messages(source)
        #expect(found.count == 3)
        #expect(found.allSatisfy { $0.hasPrefix("context.world is only valid during the lifecycle callback") })
    }

    @Test("Capability annotations outside an @system class are rejected")
    func misplacedAnnotations() {
        let source = """
            @exclusiveWorld
            class Plain {
                @events(Damage) var hits;
            }
            @system(id: "bad")
            class Bad {
                @eventWriter() var out;
                func update(context) {}
            }
            """
        let found = messages(source)
        #expect(found.contains("@exclusiveWorld can only annotate an @system class"))
        #expect(found.contains("@events must annotate a stored property inside an @system class"))
        #expect(found.contains("@eventWriter requires exactly one event name"))
    }
}

@Suite("AdaScript capability diagnostic details")
struct GravityCapabilityDiagnosticDetailsTests {
    private func diagnostics(_ source: String) -> [GravityDiagnostic] {
        GravityLanguageService().analyze(text: source).diagnostics
    }

    @Test("Diagnostics point at the member, the component string and the annotation name")
    func ranges() throws {
        let source = """
            @system(id: "ranges")
            @access(read: [Health])
            class Ranges {
                func update(context) {
                    context.world.write(1, "Health", "current", 2);
                    context.world.despawnImmediate(1);
                }
            }
            @access(read: [Health])
            class Plain {}
            """
        let found = diagnostics(source)
        let lines = source.components(separatedBy: "\n")

        func text(of diagnostic: GravityDiagnostic) -> String {
            let line = Array(lines[diagnostic.range.start.line].utf16)
            let slice = line[diagnostic.range.start.utf16Column..<diagnostic.range.end.utf16Column]
            return String(decoding: slice, as: UTF16.self)
        }
        let readOnly = try #require(found.first { $0.message == "'Health' is declared read-only in @access" })
        let immediate = try #require(found.first { $0.message.hasPrefix("world.despawnImmediate requires") })
        let misplaced = try #require(found.first { $0.message.hasPrefix("@access can only annotate") })

        #expect(text(of: readOnly) == "\"Health\"")
        #expect(text(of: immediate) == "despawnImmediate")
        #expect(text(of: misplaced) == "access")
    }

    @Test("An event name may be a bare or quoted word, but not qualified or labelled")
    func eventNameForms() {
        func messages(_ annotation: String) -> [String] {
            diagnostics("""
                @system(id: "events")
                class Events {
                    \(annotation) var hits;
                    func update(context) {}
                }
                """).map(\.message)
        }
        #expect(messages("@events(Damage)").isEmpty)
        #expect(messages("@events(\"Damage\")").isEmpty)
        #expect(messages("@eventWriter(Heal)").isEmpty)
        #expect(messages("@events(Game.Damage)") == ["@events requires exactly one event name"])
        #expect(messages("@events(name: Damage)") == ["@events requires exactly one event name"])
        #expect(messages("@events(A, B)") == ["@events requires exactly one event name"])
        #expect(messages("@events") == ["@events requires exactly one event name"])
        #expect(messages("@events(3)") == ["@events requires exactly one event name"])
    }

    @Test("Only the system's own property or a global keeps the world; a local or another object does not")
    func retention() {
        let source = """
            var saved = null;
            var other = null;
            @system(id: "retain")
            class Retain {
                var kept = null;
                func update(context) {
                    var kept = context.world;
                    other.kept = context.world;
                    unknown = context.world;
                }
            }
            """
        #expect(diagnostics(source).isEmpty)
    }

    @Test("A system gets one retention diagnostic per store, at the stored name")
    func retentionRange() throws {
        let source = """
            @system(id: "retain")
            class Retain {
                var kept = null;
                func update(context) { kept = context.world; }
            }
            """
        let found = diagnostics(source)
        let diagnostic = try #require(found.first)

        #expect(found.count == 1)
        #expect(diagnostic.message.hasSuffix("do not store it in 'kept'"))
        #expect(diagnostic.range.end.utf16Column - diagnostic.range.start.utf16Column == 4)
    }

    @Test("World calls in a class that is not a system are not capability-checked")
    func plainClassIsIgnored() {
        let source = """
            class Plain {
                func run(context) {
                    context.world.despawnImmediate(1);
                    context.world.read(1, "Health", "current");
                }
            }
            """
        #expect(diagnostics(source).isEmpty)
    }

    @Test("Access sets of one system do not leak into the next")
    func accessIsPerSystem() {
        let source = """
            @system(id: "first")
            @access(read: [Health])
            class First { func update(context) { context.world.read(1, "Health", "x"); } }

            @system(id: "second")
            @access(read: [Mana])
            class Second { func update(context) { context.world.read(1, "Health", "x"); } }
            """
        #expect(diagnostics(source).map(\.message) == ["'Health' is not declared in @access"])
    }
}

@Suite("AdaScript query syntax in the language service")
struct GravityQuerySyntaxTests {
    private static let source = """
        @component(id: "game.health") struct Health { @export var current = 10; }
        @component(id: "game.target") struct Target { @export var id = 0; }
        @system(id: "combat")
        class Combat {
            @query(Game.Health as hp, optional: Target, with: [Marker], without: Frozen, changed: Health, added: Target)
            var rows;

            func update(context) {
                for (var row in rows) {
                    row.hp.current -= 1;
                }
            }
        }
        """

    @Test("Qualified names, aliases, and every query clause raise no diagnostics")
    func acceptsQueryClauses() {
        let diagnostics = GravityLanguageService().analyze(text: Self.source).diagnostics.map(\.message)
        #expect(diagnostics.isEmpty)
    }

    @Test("A row offers its aliased and optional components as members")
    func rowMembers() {
        let source = Self.source.replacingOccurrences(of: "row.hp.current -= 1;", with: "row.")
        let line = source.split(separator: "\n", omittingEmptySubsequences: false).firstIndex { $0.contains("row.") && !$0.contains("for") } ?? 0
        let column = source.split(separator: "\n", omittingEmptySubsequences: false)[line].utf16.count
        let labels = GravityLanguageService().completions(text: source, position: GravitySourcePosition(line: line, utf16Column: column)).map(\.label)

        #expect(labels.contains("hp"))
        #expect(labels.contains("target"))
        #expect(labels.contains("id"))
        #expect(!labels.contains("health"))
    }

    @Test("An aliased component offers its declared fields")
    func componentFields() {
        let source = Self.source.replacingOccurrences(of: "row.hp.current -= 1;", with: "row.hp.")
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        let line = lines.firstIndex { $0.contains("row.hp.") } ?? 0
        let labels = GravityLanguageService().completions(
            text: source,
            position: GravitySourcePosition(line: line, utf16Column: lines[line].utf16.count)
        ).map(\.label)

        #expect(labels.contains("current"))
    }
}
