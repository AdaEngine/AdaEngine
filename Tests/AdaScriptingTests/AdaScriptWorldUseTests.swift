import AdaScriptCompilerCore
import Testing

@Suite("AdaScript context.world uses")
struct AdaScriptWorldUseTests {
    private func uses(_ source: String) -> [AdaScriptWorldUse] {
        AdaScriptSyntax.parse(source: source, path: "Main.ada").worldUses
    }

    @Test("Members, bare worlds and call arguments are recorded in order")
    func members() throws {
        let found = uses("""
            class A {
                func update(context) {
                    context.world.spawn([]);
                    context.world.read(1, "Health", "current");
                    context.world.write(2, name, 3);
                    var w = context.world;
                }
            }
            """)

        #expect(found.map(\.member) == ["spawn", "read", "write", nil])
        #expect(found[0].secondArgument == nil)
        let read = try #require(found[1].secondArgument)
        #expect(read.isString)
        #expect(read.text == "Health")
        let write = try #require(found[2].secondArgument)
        #expect(!write.isString)
        #expect(write.text == "name")
    }

    @Test("The comma inside a nested list or call does not end the first argument")
    func nestedArguments() throws {
        let found = uses(#"context.world.read(f(1, 2), "Mana");"#)
        let argument = try #require(found.first?.secondArgument)

        #expect(argument.text == "Mana")
        #expect(uses("context.world.read([1, 2]);").first?.secondArgument == nil)
        #expect(uses("context.world.read();").first?.secondArgument == nil)
        #expect(uses("context.world.read").first?.secondArgument == nil)
    }

    @Test("An assignment records the stored name and how it is qualified")
    func assignments() throws {
        let found = uses("""
            saved = context.world;
            self.kept = context.world.commands;
            other.kept = context.world;
            var local = context.world;
            const fixed = context.world;
            x == context.world;
            """)

        let qualifiers = found.map { $0.assignment?.qualifier }
        #expect(qualifiers == [.bare, .selfMember, .otherMember, .declaration, .declaration, nil])
        #expect(found.compactMap { $0.assignment?.name } == ["saved", "kept", "kept", "local", "fixed"])
    }

    @Test("Ranges and offsets cover `context.world.member`")
    func ranges() throws {
        let source = "x = 1; context.world.commands.spawn();"
        let use = try #require(uses(source).first)

        #expect(String(Array(source)[use.offsets]) == "context.world.commands")
        #expect(use.memberRange?.start.utf16Column == 21)
    }

    @Test("Only the exact context.world path counts")
    func similarNames() {
        #expect(uses("mycontext.world.read(); context.worlds.read(); context.world2;").isEmpty)
    }

    @Test("Deferred commands are inferred from the system body, not from other systems")
    func deferredCommandsInference() throws {
        let source = """
            @system(id: "spawner")
            class Spawner {
                func update(context) { context.world.spawn([]); }
            }

            @system(id: "reader")
            class Reader {
                func update(context) { var n = 1; }
            }

            @system(id: "tiler")
            class Tiler {
                func update(context) { context.world.setTileOrientation(1, 2); }
            }

            @system(id: "commands")
            class Commander {
                func update(context) { context.world.commands.despawn(1); }
            }
            """
        let capabilities = try AdaScriptSchemaParser.parseSystemCapabilities(sources: [AdaScriptCompilerSource(path: "Systems.ada", source: source)])
        let byName = Dictionary(uniqueKeysWithValues: capabilities.map { ($0.systemName, $0.usesDeferredCommands) })

        #expect(byName["Spawner"] == true)
        #expect(byName["Reader"] == false)
        #expect(byName["Tiler"] == true)
        #expect(byName["Commander"] == true)
    }

    @Test("A direct read of the world does not need deferred commands")
    func immediateReadIsNotDeferred() throws {
        let source = """
            @system(id: "peek")
            class Peek {
                func update(context) { context.world.read(1, "Health", "current"); }
            }
            """
        let capabilities = try AdaScriptSchemaParser.parseSystemCapabilities(sources: [AdaScriptCompilerSource(path: "Peek.ada", source: source)])

        #expect(capabilities.first?.usesDeferredCommands == false)
    }
}
