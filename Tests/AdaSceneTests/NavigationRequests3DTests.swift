@_spi(Internal) @testable import AdaApp
import AdaAssets
import AdaECS
import AdaNavigation
import AdaNavigationBaking
import AdaPhysics
import AdaScene
import AdaTransform
import Foundation
import Math
import Testing

@MainActor
@Suite("Navigation targets and assets", .serialized)
struct NavigationRequests3DTests {
    @Test("Targets request routes, moving targets replace them, and cancellation stops movement")
    func targetsAndCancellation() async throws {
        let app = try await makeApp()
        app.insertResource(NavigationMap3D(mesh: try await mesh()))
        let entity = spawn(in: app.main)
        await app.main.runScheduler(.update)
        #expect(entity.components[NavigationAgent3DComponent.self]?.follower.state == .following)
        entity.components[NavigationTarget3DComponent.self] = NavigationTarget3DComponent(destination: [1, 0, 9])
        await app.main.runScheduler(.update)
        let route = try #require(entity.components[NavigationAgent3DComponent.self]?.follower.path)
        #expect(abs(try #require(route.points.last).x - 1) < 0.01)
        entity.components[NavigationTarget3DComponent.self] = NavigationTarget3DComponent()
        await app.main.runScheduler(.update)
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        await app.main.runScheduler(.physicsWriteback)
        #expect(entity.components[NavigationAgent3DComponent.self]?.follower.state == .idle)
        #expect(entity.components[CharacterController3DComponent.self]?.desiredVelocity == .zero)
    }

    @Test("A replacement map invalidates routes and does not keep following an unreachable goal")
    func mapReplacement() async throws {
        let app = try await makeApp()
        app.insertResource(NavigationMap3D(mesh: try await mesh()))
        let entity = spawn(in: app.main)
        await app.main.runScheduler(.update)
        let smaller = try await NavigationMeshBaker.bake(
            vertices: [[0, 0, 0], [0, 0, 3], [3, 0, 3], [3, 0, 0]], indices: [0, 1, 2, 0, 2, 3]
        )
        app.insertResource(NavigationMap3D(mesh: try NavigationMesh(data: smaller)))
        await app.main.runScheduler(.update)
        #expect(entity.components[NavigationAgent3DComponent.self]?.lastError == .targetOutsideMesh)
        #expect(entity.components[NavigationAgent3DComponent.self]?.follower.path == nil)
        app.main.insertResource(FixedTime(deltaTime: 1.0 / 60))
        await app.main.runScheduler(.physicsWriteback)
        #expect(entity.components[NavigationAgent3DComponent.self]?.lastError == .targetOutsideMesh)
    }

    @Test("The per-update request budget eventually services every agent")
    func boundedRequests() async throws {
        let app = try await makeApp()
        app.insertResource(NavigationMap3D(mesh: try await mesh(), maximumRequestsPerUpdate: 2))
        let entities = (0..<7).map { _ in spawn(in: app.main) }
        await app.main.runScheduler(.update)
        #expect(entities.filter { $0.components[NavigationAgent3DComponent.self]?.follower.path != nil }.count == 2)
        for _ in 0..<3 { await app.main.runScheduler(.update) }
        #expect(entities.allSatisfy { $0.components[NavigationAgent3DComponent.self]?.follower.state == .following })
    }

    @Test("Invalid targets stop existing routes without waiting for a query budget")
    func invalidTarget() async throws {
        let app = try await makeApp()
        app.insertResource(NavigationMap3D(mesh: try await mesh()))
        let entity = spawn(in: app.main)
        await app.main.runScheduler(.update)
        entity.components[NavigationTarget3DComponent.self] = NavigationTarget3DComponent(destination: [.nan, 0, 9])
        await app.main.runScheduler(.update)
        #expect(entity.components[NavigationAgent3DComponent.self]?.lastError == .invalidQuery)
        #expect(entity.components[NavigationAgent3DComponent.self]?.follower.path == nil)
    }

    @Test("Map replacement stops unserviced agents before their new request is processed")
    func invalidationBeforeBudget() async throws {
        let app = try await makeApp()
        let navigation = try await mesh()
        app.insertResource(NavigationMap3D(mesh: navigation))
        let entities = (0..<4).map { _ in spawn(in: app.main) }
        await app.main.runScheduler(.update)
        #expect(entities.allSatisfy { $0.components[NavigationAgent3DComponent.self]?.follower.path != nil })
        app.insertResource(NavigationMap3D(mesh: navigation, maximumRequestsPerUpdate: 1))
        await app.main.runScheduler(.update)
        #expect(entities.filter { $0.components[NavigationAgent3DComponent.self]?.follower.path != nil }.count == 1)
    }

    @Test("AssetsManager saves and loads a real navigation file")
    func assetFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try await mesh()
        let path = directory.appendingPathComponent("floor.navmesh").path
        try await AssetsManager.save(NavigationMeshAsset(data: original.data), at: path)
        let handle = try await AssetsManager.load(NavigationMeshAsset.self, at: path)
        let loaded = try #require(handle.asset)
        let navigation = try NavigationMesh(data: loaded.data)
        #expect(try await navigation.findPath(from: [1, 0, 1], to: [9, 0, 9]).status == .complete)
    }

    private func makeApp() async throws -> AppWorlds {
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(Physics3DPlugin()).addPlugin(Navigation3DPlugin())
        try await app.build()
        return app
    }

    private func mesh() async throws -> NavigationMesh {
        let data = try await NavigationMeshBaker.bake(
            vertices: [[0, 0, 0], [0, 0, 10], [10, 0, 10], [10, 0, 0]], indices: [0, 1, 2, 0, 2, 3]
        )
        return try NavigationMesh(data: data)
    }

    private func spawn(in world: World) -> Entity {
        world.spawn {
            Transform(position: [1, 0, 1])
            NavigationAgent3DComponent()
            NavigationTarget3DComponent(destination: [9, 0, 9])
            CharacterController3DComponent()
        }
    }
}
