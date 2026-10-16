@_spi(AdaEngine) import AdaEngine
import Testing

@testable import AdaEditor

@Suite("Play mode inspection")
@MainActor
struct EditorPlayInspectionTests {
    @Test("live entities appear in the picker and selection reads their components")
    func liveEntitiesAppearAndCanBeInspected() {
        let world = World(name: "Play inspection")
        let camera = world.spawn("SceneView_Camera")
        let crate = world.spawn("Crate") {
            Transform(position: Vector3(1, 2, 3))
        }
        let model = EditorPlayInspectionModel()
        model.attach(world)

        #expect(model.items.map(\.name) == ["Crate"])
        #expect(!model.items.contains(where: { $0.id == camera.id }))
        model.select(crate.id)
        #expect(model.selection?.name == "Crate")
        #expect(model.selection?.components.contains(where: { $0.name == "Transform" }) == true)
        #expect(model.selection?.components.first(where: { $0.name == "Transform" })?.value.contains("Position: 1.0, 2.0, 3.0") == true)

        _ = world.spawn("Spawned during play")
        model.refresh(force: true)
        #expect(model.items.map(\.name) == ["Crate", "Spawned during play"])
        model.select(nil)
        #expect(model.selection == nil)
    }

    @Test("game window presets and custom sizes resolve safely")
    func gameWindowSizes() {
        let projectSize = Size(width: 960, height: 640)
        #expect(EditorGameWindowSize.project.size(projectSize: projectSize, customWidth: "", customHeight: "") == projectSize)
        #expect(EditorGameWindowSize.hd.size(projectSize: projectSize, customWidth: "", customHeight: "") == Size(width: 1280, height: 720))
        #expect(EditorGameWindowSize.custom.size(projectSize: projectSize, customWidth: "1024", customHeight: "768") == Size(width: 1024, height: 768))
        #expect(EditorGameWindowSize.custom.size(projectSize: projectSize, customWidth: "99999", customHeight: "768") == nil)
    }

    @Test("Stable inventory still refreshes selected components and observes spawned or removed entities")
    func stableInventoryKeepsSelectionLive() throws {
        let world = World(name: "Large play inspection")
        for index in 0..<600 { _ = world.spawn("Entity \(index)") }
        let selected = world.spawn("Selected") { Transform() }
        let model = EditorPlayInspectionModel()
        model.attach(world)
        model.select(selected.id)
        let initial = model.selection
        let inventory = model.items
        selected.components[Transform.self] = Transform(position: Vector3(4, 5, 6))
        model.refresh(force: true)
        #expect(model.items == inventory)
        #expect(model.selection != initial)
        #expect(model.selection?.components.first(where: { $0.name == "Transform" })?.value.contains("Position: 4.0, 5.0, 6.0") == true)
        let spawned = world.spawn("A spawned entity")
        model.refresh(force: true)
        #expect(model.items.first?.id == spawned.id)
        #expect(model.selection?.name == "Selected")
        world.removeEntity(selected)
        model.refresh(force: true)
        #expect(!model.items.contains { $0.id == selected.id })
        #expect(model.selection == nil)
        #expect(model.selectedID == nil)
    }
}
