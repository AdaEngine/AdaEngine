@testable import AdaApp
@_spi(Scripting) import AdaECS
import AdaScriptCompilerCore
import AdaScripting
import Testing

@Suite("Gravity resource bindings", .serialized)
struct GravityResourceBindingTests {
    @Test("Mutates a typed resource through a pointer-backed @res binding")
    @MainActor
    func mutatesResource() async throws {
        RuntimeTypeRegistry.registerResource(ScriptBalance.self, names: ["ScriptBalance", "test.balance"])
        RuntimeResourceReflectionRegistry.register(
            ScriptBalance.self,
            fields: [Self.gravityField]
        )

        let plugin = try AdaScriptPlugin(
            source: """
            @system(id: "resource.system")
            class ResourceSystem {
                @res
                var balance: ScriptBalance;

                func update(context) {
                    balance.gravity += 1.5;
                }
            }
            """,
            name: "ResourceBinding"
        )
        let world = World(name: "Gravity resource binding")
        world.insertResource(ScriptBalance(gravity: 9.8))
        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(plugin.diagnostics.isEmpty)
        #expect(world.getResource(ScriptBalance.self)?.gravity == 11.3)
    }

    @Test("Reports a missing required resource and permits an optional resource")
    @MainActor
    func missingResources() async throws {
        RuntimeTypeRegistry.registerResource(ScriptBalance.self, names: ["ScriptBalance", "test.balance"])
        RuntimeResourceReflectionRegistry.register(ScriptBalance.self, fields: [Self.gravityField])

        let plugin = try AdaScriptPlugin(
            source: """
            @system(id: "resource.system")
            class ResourceSystem {
                @res
                var required: ScriptBalance;

                @res(optional: true)
                var optional: ScriptBalance;

                func update(context) {
                    if (optional.available()) {
                        optional.gravity += 1.0;
                    }
                }
            }
            """,
            name: "MissingResourceBinding"
        )
        let world = World(name: "Missing Gravity resource binding")
        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(plugin.diagnostics == ["Required resource 'ScriptBalance' is not available"])
    }

    @Test("Infers read or write resource access from how the binding is used")
    func infersResourceAccess() throws {
        func access(_ body: String, annotation: String = "@res") throws -> AdaScriptResourceBinding.Access? {
            try AdaScriptSchemaParser.parseResourceBindings(sources: [
                AdaScriptCompilerSource(path: "A.ada", source: """
                @system(id: "s")
                class S {
                    \(annotation)
                    var balance: ScriptBalance;
                    func update(context) { \(body) }
                }
                """)
            ]).first?.access
        }
        #expect(try access("var g = balance.gravity;") == .read)
        #expect(try access("if (balance.gravity == 1.0) { put(1); }") == .read)
        #expect(try access("balance.gravity += 1.5;") == .write)
        #expect(try access("balance.gravity = 2.0;") == .write)
        #expect(try access("self.balance.gravity -= 1.0;") == .write)
        #expect(try access("var alias = balance; alias.gravity = 2.0;") == .write)
        #expect(try access("") == .read)
        #expect(try access("balance.reset();") == .write)
        #expect(try access("var g = balance.gravity;", annotation: "@res(access: \"write\")") == .write)
        #expect(try access("var g = balance.gravity;", annotation: "@res(access: \"read\")") == .read)
    }

    @Test("A read-only declaration is rejected when the body writes through the binding")
    func rejectsWriteUnderReadDeclaration() {
        #expect(throws: (any Error).self) {
            _ = try AdaScriptSchemaParser.parseResourceBindings(sources: [
                AdaScriptCompilerSource(path: "A.ada", source: """
                @system(id: "s")
                class S {
                    @res(access: "read")
                    var balance: ScriptBalance;
                    func update(context) { balance.gravity = 1.0; }
                }
                """)
            ])
        }
        #expect(throws: (any Error).self) {
            _ = try AdaScriptSchemaParser.parseResourceBindings(sources: [
                AdaScriptCompilerSource(path: "A.ada", source: """
                @system(id: "s")
                class S {
                    @res(access: "execute")
                    var balance: ScriptBalance;
                    func update(context) {}
                }
                """)
            ])
        }
    }

    @Test("A read-only resource binding reserves read access and still reads")
    @MainActor
    func readOnlyBindingReads() async throws {
        RuntimeTypeRegistry.registerResource(ScriptBalance.self, names: ["ScriptBalance", "test.balance"])
        RuntimeResourceReflectionRegistry.register(ScriptBalance.self, fields: [Self.gravityField])
        let plugin = try AdaScriptPlugin(
            source: """
            var seen = 0.0;

            @system(id: "reader")
            class Reader {
                @res
                var balance: ScriptBalance;
                func update(context) { seen = balance.gravity; }
            }
            """,
            name: "ReadOnlyResource"
        )
        let world = World(name: "Read only resource")
        world.insertResource(ScriptBalance(gravity: 4.0))
        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(plugin.diagnostics.isEmpty)
        #expect(world.getResource(ScriptBalance.self)?.gravity == 4.0)
        let reader = DynamicResource(resourceType: ScriptBalance.self, isOptional: false, writable: false)
        var otherReader = SystemAccessSet()
        otherReader.addResourceRead(ScriptBalance.self)
        #expect(reader.access.isCompatible(with: otherReader))
        #expect(!reader.isWritable)
    }

    @safe
    private static let gravityField = unsafe ReflectedComponentField(
        key: "gravity",
        label: "gravity",
        kind: .float,
        isWritable: true,
        accepts: { ComponentReflection.accepts($0, for: Double.self) },
        read: { _ in nil },
        write: { _, _ in nil },
        readPointer: { pointer in
            let resource = unsafe pointer.assumingMemoryBound(to: ScriptBalance.self)
            return ComponentReflection.read(unsafe resource.pointee.gravity)
        },
        writePointer: { pointer, value in
            let resource = unsafe pointer.assumingMemoryBound(to: ScriptBalance.self)
            return unsafe ComponentReflection.write(value, to: &resource.pointee.gravity)
        }
    )
}

private struct ScriptBalance: Resource {
    var gravity: Double
}
