@_spi(Internal) import AdaApp
@_spi(Scripting) import AdaECS
import AdaNavigation
import AdaNavigationBaking
import AdaPhysics
import AdaScene
import AdaScriptAOTFixture
import AdaScripting
import AdaTransform
import Foundation
import GravityAOT
import Math
import Testing

@MainActor
@Suite("AdaScript navigation", .serialized)
struct NavigationScriptTests {
    @Test("AOT-compiled AdaScript sets a goal, arrives through physics and clears it with null")
    func nativeScriptDrivesPhysics() async throws {
        let app = try await makeApp()
        let character = spawn(in: app.main)
        let pointer = try #require(ada_native_navigation_get_module())
        let module = unsafe try NativeModule(module: pointer)
        let script = try AdaScriptNativePlugin(module: module, name: "NativeNavigation")
        script.setup(in: app)
        await app.main.runScheduler(.physicsSync)
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        for _ in 0..<900 {
            await app.main.runScheduler(.update)
            await app.main.runScheduler(.physicsStep)
            await app.main.runScheduler(.physicsWriteback)
            if app.main.getResource(AdaScriptNativeResources.self)?.values["navigation.native.report"]?["arrivals"] == .int(1) { break }
        }
        for _ in 0..<2 { await app.main.runScheduler(.update) }
        await app.main.runScheduler(.physicsWriteback)
        #expect(app.main.getResource(AdaScriptNativeResources.self)?.values["navigation.native.report"]?["arrivals"] == .int(1))
        #expect(character.components[NavigationTarget3DComponent.self]?.destination == nil)
        #expect(character.components[NavigationAgent3DComponent.self]?.state == "idle")
        #expect(character.components[CharacterController3DComponent.self]?.desiredVelocity == .zero)
        #expect(script.diagnostics.isEmpty)
    }

    @Test("A real script sets a goal, controls speed and observes physical arrival around an obstacle")
    func scriptDrivesPhysics() async throws {
        let app = try await makeApp()
        let character = spawn(in: app.main)
        let script = try install("""
            var assigned = false;
            if (!assigned) {
                row.navigationTarget3DComponent.destination = [11.0, 0.0, 6.0];
                row.navigationAgent3DComponent.maximumSpeed = 4.0;
                assigned = true;
            }
            """, in: app)
        await app.main.runScheduler(.physicsSync)
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        for _ in 0..<900 {
            await app.main.runScheduler(.update)
            await app.main.runScheduler(.physicsStep)
            await app.main.runScheduler(.physicsWriteback)
            if character.components[NavigationAgent3DComponent.self]?.hasArrived == true { break }
        }
        await app.main.runScheduler(.update)
        let agent = try #require(character.components[NavigationAgent3DComponent.self])
        #expect(agent.hasArrived)
        #expect(agent.maximumSpeed == 4)
        #expect(agent.pathPointCount > 2)
        #expect(read("state", in: app.main, entity: character.id) == .string("arrived"))
        #expect(read("arrived", in: app.main, entity: character.id) == .bool(true))
        #expect(script.diagnostics.isEmpty)
    }

    @Test("A script clears a target with null and observes an unreachable destination")
    func cancellationAndFailure() async throws {
        let app = try await makeApp()
        let character = spawn(in: app.main)
        character.components[NavigationTarget3DComponent.self] = NavigationTarget3DComponent(destination: [100, 0, 100])
        let observer = try install("", in: app)
        await app.main.runScheduler(.update)
        await app.main.runScheduler(.update)
        #expect(read("state", in: app.main, entity: character.id) == .string("failed"))
        #expect(read("error", in: app.main, entity: character.id) == .string("targetOutsideMesh"))
        let cancel = try AdaScriptPlugin(source: """
            @system(id: "navigation.cancel") class Cancel {
                @query(NavigationTarget3DComponent) var robots;
                func update(context) {
                    for (var row in robots) { row.navigationTarget3DComponent.destination = null; }
                }
            }
            """, name: "CancelNavigation")
        cancel.setup(in: app)
        for _ in 0..<3 { await app.main.runScheduler(.update) }
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        await app.main.runScheduler(.physicsWriteback)
        #expect(character.components[NavigationTarget3DComponent.self]?.destination == nil)
        #expect(character.components[NavigationAgent3DComponent.self]?.state == "idle")
        #expect(character.components[CharacterController3DComponent.self]?.desiredVelocity == .zero)
        #expect(observer.diagnostics.isEmpty && cancel.diagnostics.isEmpty)
    }

    @Test("Script constructors create agents and targets through the registered factories")
    func constructsComponents() async throws {
        let app = try await makeApp()
        let script = try AdaScriptPlugin(source: """
            @system(id: "navigation.spawn") class Spawn {
                var done = false;
                func update(context) {
                    if (!done) {
                        context.world.spawn([NavigationAgent3DComponent(), NavigationTarget3DComponent(destination: [11.0, 0.0, 6.0])]);
                        done = true;
                    }
                }
            }
            """, name: "SpawnNavigation")
        script.setup(in: app)
        await app.main.runScheduler(.update)
        app.main.flush()
        let entity = try #require(app.main.getEntities().first { $0.components[NavigationAgent3DComponent.self] != nil })
        #expect(entity.components[NavigationTarget3DComponent.self]?.destination == [11, 0, 6])
        #expect(script.diagnostics.isEmpty)
    }

    @Test("Script writes cannot forge read-only state")
    func readOnlyState() async throws {
        let app = try await makeApp()
        let character = spawn(in: app.main)
        let script = try AdaScriptPlugin(source: """
            @system(id: "navigation.invalid-write") class InvalidWrite {
                @query(NavigationAgent3DComponent) var robots;
                func update(context) { for (var row in robots) { row.navigationAgent3DComponent.state = "arrived"; } }
            }
            """, name: "ReadOnlyNavigation")
        script.setup(in: app)
        await app.main.runScheduler(.update)
        #expect(character.components[NavigationAgent3DComponent.self]?.hasArrived == false)
        #expect(!script.diagnostics.isEmpty)
        #expect(!NavigationAgent3DComponent.componentDescriptor.fields.contains { $0.key == "requestSerial" })
    }

    private func makeApp() async throws -> AppWorlds {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(Physics3DPlugin()).addPlugin(Navigation3DPlugin())
        try await app.build()
        var vertices: [Vector3] = []
        var indices: [UInt32] = []
        let rectangles: [(Float, Float, Float, Float)] = [(0, 4, 0, 12), (8, 12, 0, 12), (4, 8, 0, 4), (4, 8, 8, 12)]
        for (minX, maxX, minZ, maxZ) in rectangles {
            let base = UInt32(vertices.count)
            vertices += [[minX, 0, minZ], [minX, 0, maxZ], [maxX, 0, maxZ], [maxX, 0, minZ]]
            indices += [0, 1, 2, 0, 2, 3].map { base + $0 }
        }
        let data = try await NavigationMeshBaker.bake(vertices: vertices, indices: indices)
        app.insertResource(NavigationMap3D(mesh: try NavigationMesh(data: data)))
        app.main.spawn {
            Transform(position: [6, -0.5, 6])
            PhysicsBody3DComponent(shapes: [.generateBox(width: 14, height: 1, depth: 14)], mode: .static)
        }
        app.main.spawn {
            Transform(position: [6, 1.5, 6])
            PhysicsBody3DComponent(shapes: [.generateBox(width: 4, height: 3, depth: 4)], mode: .static)
        }
        return app
    }

    private func spawn(in world: World) -> Entity {
        world.spawn {
            Transform(position: [1, 0, 6])
            CharacterController3DComponent()
            NavigationAgent3DComponent()
            NavigationTarget3DComponent()
        }
    }

    private func install(_ body: String, in app: AppWorlds) throws -> AdaScriptPlugin {
        // The declaration stays outside the loop so the assignment happens once per system instance.
        let declarations = body.contains("var assigned") ? "var assigned = false;" : ""
        let commands = body.replacingOccurrences(of: "var assigned = false;", with: "")
        let script = try AdaScriptPlugin(source: """
            @component(id: "navigation.observation") struct NavigationObservation {
                @export var state = "";
                @export var error = "";
                @export var arrived = false;
            }
            @system(id: "navigation.control") class NavigationControl {
                @query(NavigationTarget3DComponent, NavigationAgent3DComponent, NavigationObservation) var robots;
                \(declarations)
                func update(context) {
                    for (var row in robots) {
                        \(commands)
                        row.navigationObservation.state = row.navigationAgent3DComponent.state;
                        row.navigationObservation.error = row.navigationAgent3DComponent.errorCode;
                        row.navigationObservation.arrived = row.navigationAgent3DComponent.hasArrived;
                    }
                }
            }
            """, name: "ScriptNavigation")
        script.setup(in: app)
        let descriptor = try #require(app.main.runtimeComponentDescriptor(named: "NavigationObservation"))
        for entity in app.main.getEntities() where entity.components[NavigationAgent3DComponent.self] != nil {
            app.main.insert(descriptor.makeDefault(), for: entity.id)
        }
        return script
    }

    private func read(_ key: String, in world: World, entity: Entity.ID) -> ReflectedFieldValue? {
        guard let descriptor = world.runtimeComponentDescriptor(named: "NavigationObservation"),
            let field = descriptor.fields.first(where: { $0.key == key }) else { return nil }
        return world.readComponentField(component: descriptor.componentID, entity: entity, field: field)
    }
}
