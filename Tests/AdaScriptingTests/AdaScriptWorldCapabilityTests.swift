@testable import AdaApp
import AdaECS
import AdaScripting
import Math
import Testing

@Suite("AdaScript world capabilities", .serialized)
struct AdaScriptWorldCapabilityTests {
    @Test("Inserts a constructed component with field overrides through deferred commands")
    @MainActor
    func insertsConstructedComponent() async throws {
        registerComponents()
        let plugin = try AdaScriptPlugin(
            source: """
            @system(id: "insert.system")
            class InsertSystem {
                @query(CapabilityMarker)
                var entities;

                func update(context) {
                    for (var entity in entities) {
                        context.world.commands.insert(entity.id, CapabilityStats(count: 9, position: Vector3(1, 2, 3)));
                    }
                }
            }
            """,
            name: "InsertConstructor"
        )
        let world = World(name: "Insert constructor")
        let target = world.spawn { CapabilityMarker() }

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        let stats = try #require(world.get(CapabilityStats.self, from: target.id))
        #expect(plugin.diagnostics.isEmpty)
        #expect(stats.count == 9)
        #expect(stats.position == Vector3(1, 2, 3))
    }

    @Test("Delivers an event written in one frame to a reader in the next")
    @MainActor
    func deliversEventsBetweenSystems() async throws {
        registerComponents()
        let plugin = try AdaScriptPlugin(
            source: """
            @system(id: "damage.writer")
            class DamageWriter {
                @eventWriter(Damage)
                var damage;

                func update(context) {
                    damage.send(["amount", 5, "source", "trap"]);
                }
            }

            @system(id: "damage.reader")
            class DamageReader {
                @events(Damage)
                var hits;
                @query(CapabilityStats)
                var stats;

                func update(context) {
                    for (var hit in hits) {
                        for (var row in stats) {
                            row.capabilityStats.count += hit.value.amount;
                        }
                    }
                }
            }
            """,
            name: "ScriptEvents"
        )
        let world = makeEventWorld()
        let target = world.spawn { CapabilityStats() }

        plugin.setup(in: AppWorlds(main: world))
        await runFrame(world)
        #expect(world.get(CapabilityStats.self, from: target.id)?.count == 0)
        await runFrame(world)

        #expect(plugin.diagnostics.isEmpty)
        #expect(world.get(CapabilityStats.self, from: target.id)?.count == 5)
    }

    @Test("Events are filtered by the declared name")
    @MainActor
    func filtersEventsByName() async throws {
        registerComponents()
        let plugin = try AdaScriptPlugin(
            source: """
            @system(id: "heal.writer")
            class HealWriter {
                @eventWriter(Heal)
                var heal;
                func update(context) { heal.send(["amount", 3]); }
            }

            @system(id: "damage.reader")
            class DamageReader {
                @events(Damage)
                var hits;
                @query(CapabilityStats)
                var stats;
                func update(context) {
                    for (var hit in hits) {
                        for (var row in stats) { row.capabilityStats.count += 100; }
                    }
                }
            }
            """,
            name: "FilteredEvents"
        )
        let world = makeEventWorld()
        let target = world.spawn { CapabilityStats() }

        plugin.setup(in: AppWorlds(main: world))
        await runFrame(world)
        await runFrame(world)

        #expect(plugin.diagnostics.isEmpty)
        #expect(world.get(CapabilityStats.self, from: target.id)?.count == 0)
    }

    @Test("Dynamic access is limited to the declared @access set")
    @MainActor
    func enforcesDeclaredAccess() async throws {
        registerComponents()
        let plugin = try AdaScriptPlugin(
            source: """
            var observed = 0;

            @system(id: "dynamic.system")
            @access(read: [CapabilityMarker], write: [CapabilityStats])
            class DynamicSystem {
                @query(CapabilityMarker)
                var markers;

                func update(context) {
                    for (var entity in markers) {
                        context.world.write(entity.id, "CapabilityStats", "count", 4);
                        observed = context.world.read(entity.id, "CapabilityStats", "count");
                        context.world.write(entity.id, "CapabilityMarker", "unused", 1);
                        context.world.read(entity.id, "CapabilityConfigured", "count");
                    }
                }
            }
            """,
            name: "DynamicAccess"
        )
        let world = World(name: "Dynamic access")
        let target = world.spawn {
            CapabilityMarker()
            CapabilityStats()
        }

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(world.get(CapabilityStats.self, from: target.id)?.count == 4)
        #expect(plugin.diagnostics.contains("Component 'CapabilityMarker' is declared read-only in this system's @access set"))
        #expect(plugin.diagnostics.contains("Component 'CapabilityConfigured' is not declared in this system's @access set"))
    }

    @Test("The dynamic world API requires an @access declaration")
    @MainActor
    func rejectsDynamicAccessWithoutDeclaration() async throws {
        registerComponents()
        let plugin = try AdaScriptPlugin(
            source: """
            @system(id: "undeclared.dynamic")
            class UndeclaredDynamic {
                func update(context) {
                    context.world.read(1, "CapabilityStats", "count");
                }
            }
            """,
            name: "UndeclaredDynamic"
        )
        let world = World(name: "Undeclared dynamic")

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(plugin.diagnostics == ["world.read requires an explicit @access declaration on the system"])
    }

    @Test("An exclusive system applies structural changes immediately")
    @MainActor
    func appliesImmediateOperations() async throws {
        registerComponents()
        let plugin = try AdaScriptPlugin(
            source: """
            var spawnedID = -1;
            var visibleRightAway = false;

            @system(id: "bootstrap.system", scheduler: "startup")
            @exclusiveWorld
            class BootstrapSystem {
                func update(context) {
                    spawnedID = context.world.spawnImmediate([CapabilityStats(count: 2)]);
                    context.world.insertImmediate(spawnedID, "test.marker");
                    context.world.removeImmediate(spawnedID, "test.marker");
                    context.world.insertImmediate(spawnedID, "test.marker");
                }
            }
            """,
            name: "ExclusiveWorld"
        )
        let world = World(name: "Exclusive world")

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.startup)

        let spawned = try #require(world.getEntities().first)
        #expect(plugin.diagnostics.isEmpty)
        #expect(world.get(CapabilityStats.self, from: spawned.id)?.count == 2)
        #expect(world.get(CapabilityMarker.self, from: spawned.id) != nil)
    }

    @Test("Immediate operations are rejected for a system that is not exclusive")
    @MainActor
    func rejectsImmediateOperationsWithoutDeclaration() async throws {
        registerComponents()
        let plugin = try AdaScriptPlugin(
            source: """
            @system(id: "plain.system")
            class PlainSystem {
                func update(context) {
                    context.world.spawnImmediate([]);
                }
            }
            """,
            name: "PlainImmediate"
        )
        let world = World(name: "Plain immediate")

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(world.getEntities().isEmpty)
        #expect(plugin.diagnostics == ["world.spawnImmediate requires an @exclusiveWorld system"])
    }

    @Test("Immediate mutation is rejected while a query iterator is active")
    @MainActor
    func rejectsImmediateMutationDuringIteration() async throws {
        registerComponents()
        let plugin = try AdaScriptPlugin(
            source: """
            @system(id: "iterating.system")
            @exclusiveWorld
            class IteratingSystem {
                @query(CapabilityMarker)
                var markers;

                func update(context) {
                    for (var entity in markers) {
                        context.world.despawnImmediate(entity.id);
                    }
                }
            }
            """,
            name: "ImmediateDuringIteration"
        )
        let world = World(name: "Immediate during iteration")
        let target = world.spawn { CapabilityMarker() }

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(world.get(CapabilityMarker.self, from: target.id) != nil)
        #expect(plugin.diagnostics.contains("world.despawnImmediate cannot run while a query iterator is active"))
    }

    @Test("Capability annotations on non-system targets are rejected")
    @MainActor
    func rejectsMisplacedCapabilityAnnotations() throws {
        #expect(throws: AdaScriptError.self) {
            _ = try AdaScriptPlugin(
                source: """
                @exclusiveWorld
                class NotASystem { func update(context) {} }
                """,
                name: "MisplacedExclusive"
            )
        }
        #expect(throws: AdaScriptError.self) {
            _ = try AdaScriptPlugin(
                source: """
                @system(id: "loose.event")
                class LooseEvent {
                    @events(Damage, Heal)
                    var hits;
                    func update(context) {}
                }
                """,
                name: "AmbiguousEvents"
            )
        }
    }

    @Test("Event capabilities require the events lifecycle")
    @MainActor
    func eventsRequireEventsPlugin() async throws {
        registerComponents()
        let plugin = try AdaScriptPlugin(
            source: """
            @system(id: "needs.events")
            class NeedsEvents {
                @eventWriter(Damage)
                var damage;
                func update(context) { damage.send([]); }
            }
            """,
            name: "NeedsEventsPlugin"
        )
        let world = World(name: "No events plugin")

        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(plugin.diagnostics.contains { $0.contains("requires EventsPlugin") })
    }

    @MainActor
    private func makeEventWorld() -> World {
        let world = World(name: "Script events")
        world.insertResource(HandledEvents())
        world.addSystem(EventsUpdateSystem.self, on: .preUpdate)
        return world
    }

    @MainActor
    private func runFrame(_ world: World) async {
        await world.runScheduler(.preUpdate)
        await world.runScheduler(.update)
    }

    @MainActor
    private func registerComponents() {
        RuntimeTypeRegistry.registerComponent(CapabilityMarker.self, names: ["CapabilityMarker", "test.marker"], makeDefault: { CapabilityMarker() })
        RuntimeTypeRegistry.registerComponent(CapabilityStats.self, names: ["CapabilityStats"], makeDefault: { CapabilityStats() })
        ComponentReflectionRegistry.register(CapabilityMarker.componentDescriptor)
        ComponentReflectionRegistry.register(CapabilityStats.componentDescriptor)
    }
}

@Component
private struct CapabilityMarker {
    var unused: Int = 0
}

@Component
private struct CapabilityStats {
    var count: Int = 0
    var position: Vector3 = .zero
}
