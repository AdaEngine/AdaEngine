@testable import AdaApp
@_spi(Scripting) import AdaECS
import AdaScriptCompilerCore
@testable import AdaScripting
import Testing

@Suite("AdaScript query clauses, aliases, and access", .serialized)
struct AdaScriptQueryClauseTests {
    @MainActor
    private func register() {
        RuntimeTypeRegistry.registerComponent(QueryCounter.self, names: ["QueryCounter"], makeDefault: { QueryCounter() })
        RuntimeTypeRegistry.registerComponent(QueryTarget.self, names: ["QueryTarget"], makeDefault: { QueryTarget() })
        RuntimeTypeRegistry.registerComponent(QueryMarker.self, names: ["QueryMarker"], makeDefault: { QueryMarker() })
        RuntimeTypeRegistry.registerComponent(QueryThingA.self, names: ["Alpha.Thing"], makeDefault: { QueryThingA() })
        RuntimeTypeRegistry.registerComponent(QueryThingB.self, names: ["Beta.Thing"], makeDefault: { QueryThingB() })
        for descriptor in [QueryCounter.componentDescriptor, QueryTarget.componentDescriptor, QueryThingA.componentDescriptor, QueryThingB.componentDescriptor] {
            ComponentReflectionRegistry.register(descriptor)
        }
    }

    private func compile(_ source: String) -> (plugin: AdaScriptPlugin?, error: String) {
        do {
            return (try AdaScriptPlugin(source: source, name: "QueryClauses"), "")
        } catch {
            return (nil, String(describing: error))
        }
    }

    @Test("An optional component is fetched when present and null when the row lacks it")
    @MainActor
    func optionalComponents() async throws {
        register()
        let plugin = try #require(compile("""
            @system(id: "optional.system")
            class OptionalSystem {
                @query(QueryCounter, optional: QueryTarget)
                var rows;

                func update(context) {
                    for (var row in rows) {
                        if (row.queryTarget == null) {
                            row.queryCounter.count = 100;
                        } else {
                            row.queryCounter.count = row.queryTarget.id;
                        }
                    }
                }
            }
            """).plugin)
        let world = World(name: "Optional rows")
        let with = world.spawn { QueryCounter(); QueryTarget(id: 7) }
        let without = world.spawn { QueryCounter() }
        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(plugin.diagnostics.isEmpty)
        #expect(world.get(QueryCounter.self, from: with.id)?.count == 7)
        #expect(world.get(QueryCounter.self, from: without.id)?.count == 100)
    }

    @Test("Aliases rename row properties and qualified names resolve")
    @MainActor
    func aliases() async throws {
        register()
        let plugin = try #require(compile("""
            @system(id: "alias.system")
            class AliasSystem {
                @query(Alpha.Thing as first, Beta.Thing as second, QueryCounter)
                var rows;

                func update(context) {
                    for (var row in rows) {
                        row.queryCounter.count = row.first.value + row.second.value;
                    }
                }
            }
            """).plugin)
        let world = World(name: "Aliased rows")
        let entity = world.spawn { QueryCounter(); QueryThingA(value: 3); QueryThingB(value: 4) }
        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(plugin.diagnostics.isEmpty)
        #expect(world.get(QueryCounter.self, from: entity.id)?.count == 7)
    }

    @Test("Two components with the same short name need an alias")
    @MainActor
    func duplicateShortNames() throws {
        register()
        let plugin = try #require(compile("""
            @system(id: "clash.system")
            class ClashSystem {
                @query(Alpha.Thing, Beta.Thing)
                var rows;
                func update(context) { for (var row in rows) { put(row.id); } }
            }
            """).plugin)
        let world = World(name: "Clash")
        plugin.setup(in: AppWorlds(main: world))

        #expect(plugin.diagnostics.contains { $0.contains("fetches 'Alpha.Thing' and 'Beta.Thing' as 'thing'") && $0.contains("give one an alias") })
    }

    @Test("changed and added filters select rows touched since the system last ran")
    @MainActor
    func tickClauses() async throws {
        register()
        let plugin = try #require(compile("""
            @system(id: "ticks.system")
            class TicksSystem {
                @query(QueryCounter, added: QueryMarker)
                var fresh;
                @query(QueryCounter, with: QueryMarker, changed: QueryCounter)
                var touched;

                func update(context) {
                    for (var row in fresh) { row.queryCounter.count += 1000; }
                }
            }
            """).plugin)
        let world = World(name: "Tick clauses")
        let old = world.spawn { QueryCounter(); QueryMarker() }
        world.clearTrackers()
        world.clearTrackers()
        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)
        #expect(world.get(QueryCounter.self, from: old.id)?.count == 0)

        let new = world.spawn { QueryCounter(); QueryMarker() }
        await world.runScheduler(.update)
        #expect(world.get(QueryCounter.self, from: new.id)?.count == 1000)
        #expect(world.get(QueryCounter.self, from: old.id)?.count == 0)
        #expect(plugin.diagnostics.isEmpty)
    }

    @Test("Unsupported query clauses are rejected with a hint")
    @MainActor
    func unsupportedClauses() {
        register()
        let message = compile("""
            @system(id: "where.system")
            class WhereSystem {
                @query(QueryCounter, where: has(QueryMarker))
                var rows;
                func update(context) {}
            }
            """).error
        #expect(message.contains("@query does not support 'where:'"))
        #expect(message.contains("boolean predicates are not supported yet"))
        #expect(compile("@system(id: \"x\") class X { @query(QueryCounter, whenever: A) var rows; func update(context) {} }").error.contains("'whenever:'"))
    }

    @Test("Access is inferred from how rows are used, so readers do not conflict")
    @MainActor
    func accessInference() throws {
        register()
        let plugin = try #require(compile("""
            @system(id: "reader.system")
            class ReaderSystem {
                @query(QueryCounter, QueryTarget)
                var rows;
                func update(context) {
                    for (var row in rows) {
                        var total = row.queryCounter.count + row.queryTarget.id;
                        row.queryTarget.id = total;
                    }
                }
            }
            """).plugin)
        let world = World(name: "Inference")
        let plan = try #require(plugin.plans.first?.queries.first)
        let prepared = try AdaScriptPlugin.prepareQuery(plan, systemIdentifier: "reader.system", queryIndex: 0, world: world)

        var readsCounter = SystemAccessSet()
        readsCounter.addComponentRead(QueryCounter.self)
        var writesTarget = SystemAccessSet()
        writesTarget.addComponentWrite(QueryTarget.self)
        // Counter is only read, so another reader of Counter may run alongside; Target is written.
        #expect(prepared.query.access.isCompatible(with: readsCounter))
        #expect(!prepared.query.access.isCompatible(with: writesTarget))
        #expect(prepared.componentAccesses.first { $0.alias == "queryCounter" }?.isWritable == false)
        #expect(prepared.componentAccesses.first { $0.alias == "queryTarget" }?.isWritable == true)
    }

    @Test("Rows that escape analysis require @access, and a declaration may not claim less than the code does")
    @MainActor
    func opaqueAccess() throws {
        register()
        func source(_ access: String) -> String {
            """
            func inspect(row) { return row.queryCounter.count; }
            @system(id: "escape.system")
            \(access)
            class EscapeSystem {
                @query(QueryCounter)
                var rows;
                func update(context) { for (var row in rows) { inspect(row); } }
            }
            """
        }
        let undeclared = compile(source("")).plugin
        let world = World(name: "Opaque")
        undeclared?.setup(in: AppWorlds(main: world))
        #expect(undeclared?.diagnostics.contains { $0.contains("cannot analyse") && $0.contains("declare @access") } == true)

        let declared = try #require(compile(source("@access(read: [QueryCounter])")).plugin)
        let plan = try #require(declared.plans.first?.queries.first)
        let prepared = try AdaScriptPlugin.prepareQuery(
            plan, systemIdentifier: "escape.system", queryIndex: 0, world: world, declaredAccess: [QueryCounter.identifier: .read]
        )
        #expect(prepared.componentAccesses.first?.isWritable == false)

        let tooLittle = compile("""
            @system(id: "liar.system")
            @access(read: [QueryCounter])
            class LiarSystem {
                @query(QueryCounter) var rows;
                func update(context) { for (var row in rows) { row.queryCounter.count = 1; } }
            }
            """).plugin
        tooLittle?.setup(in: AppWorlds(main: World(name: "Liar")))
        #expect(tooLittle?.diagnostics.contains { $0.contains("writes 'QueryCounter'") && $0.contains("read-only") } == true)
    }

    @Test("Query references with paths and aliases lower to strings Gravity accepts")
    func lowering() {
        let lowered = AdaScriptQueryLowerer.lower(source: """
            @query(Game.Health as hp, Movement, optional: [Combat.Target as foe, Plain], with: Game.Tag, changed: Health) var rows;
            """)
        #expect(lowered == """
            @query("Game.Health as hp", Movement, optional: ["Combat.Target as foe", Plain], with: "Game.Tag", changed: Health) var rows;
            """)
        #expect(AdaScriptQueryLowerer.lower(source: "@query(Health) var rows;") == "@query(Health) var rows;")
    }
}

@Component
private struct QueryCounter {
    var count: Int = 0
}

@Component
private struct QueryTarget {
    var id: Int = 0
}

@Component
private struct QueryMarker {}

@Component
private struct QueryThingA {
    var value: Int = 0
}

@Component
private struct QueryThingB {
    var value: Int = 0
}
