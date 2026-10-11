@_spi(Internal) import AdaEngine
import Foundation
import Testing

@testable import AdaEditor

@Suite("Immersive scene navigation", .serialized)
@MainActor
struct EditorVRNavigationTests {
    private func world() -> World {
        let world = World()
        world.insertResource(SpatialTrackingFrame())
        world.insertResource(SpatialInput())
        world.insertResource(SpatialSelection())
        world.insertResource(DeltaTime(deltaTime: 0.02))
        return world
    }

    private func pinches(_ distance: Float) -> [SpatialGrip] {
        [
            SpatialGrip(interactor: .leftHand, pose: Transform3D(translation: [-distance / 2, 0, 0.5])),
            SpatialGrip(interactor: .rightHand, pose: Transform3D(translation: [distance / 2, 0, 0.5])),
        ]
    }

    @Test("Spreading two pinches approaches the scene; closing them retreats without object input")
    func twoHandDolly() {
        let world = world()
        let navigation = EditorVRNavigationController()
        world.insertResource(SpatialInput(grips: pinches(0.4)))
        #expect(navigation.update(in: world) == .zero)
        #expect(navigation.isNavigating)
        world.insertResource(SpatialInput(grips: pinches(0.5)))
        #expect(navigation.update(in: world).z > 0)
        #expect(world.getResource(SpatialInput.self)?.grips.isEmpty == true)
        world.insertResource(SpatialInput(grips: pinches(0.4)))
        #expect(navigation.update(in: world).z < 0)
    }

    @Test("Releasing one hand does not hand the held pinch to object manipulation")
    func releaseLatch() {
        let world = world()
        let navigation = EditorVRNavigationController()
        world.insertResource(SpatialInput(grips: pinches(0.4)))
        _ = navigation.update(in: world)
        for _ in 0..<2 {
            world.insertResource(SpatialInput(grips: [pinches(0.4)[0]]))
            #expect(navigation.update(in: world) == .zero)
            #expect(world.getResource(SpatialInput.self)?.grips.isEmpty == true)
        }
        world.insertResource(SpatialInput())
        _ = navigation.update(in: world)
        #expect(!navigation.isNavigating)
        world.insertResource(SpatialInput(grips: pinches(0.4)))
        #expect(navigation.update(in: world) == .zero)
        #expect(navigation.isNavigating)
    }

    @Test("An active object grab retains its original two-hand input")
    func objectGrabWins() {
        let world = world()
        let navigation = EditorVRNavigationController()
        world.insertResource(SpatialSelection(entityID: 1, isGrabbed: true))
        world.insertResource(SpatialInput(grips: pinches(0.4)))
        #expect(navigation.update(in: world, keys: [.w], wheel: 1) == .zero)
        #expect(world.getResource(SpatialInput.self)?.grips.count == 2)
        #expect(!navigation.isNavigating)
    }

    @Test("WASD follows head heading at a constant speed; wheel changes distance")
    func keyboardAndWheel() {
        let world = world()
        let navigation = EditorVRNavigationController()
        #expect(abs(navigation.update(in: world, keys: [.w]).z - 0.04) < 0.0001)
        #expect(abs(navigation.update(in: world, keys: [.w, .d]).length - 0.04) < 0.0001)
        #expect(navigation.update(in: world, keys: [.w, .s, .a, .d]) == .zero)
        #expect(navigation.update(in: world, wheel: 1).z > 0)
        #expect(navigation.update(in: world, wheel: -1).z < 0)
        world.insertResource(SpatialTrackingFrame(head: Transform3D(quat: Quat(axis: [0, 1, 0], angle: .pi / 2))))
        #expect(abs(navigation.update(in: world, keys: [.w]).x) > 0.039)
    }

    @Test("Text focus suppresses held movement keys until release, and rejects non-finite wheel")
    func typingDoesNotNavigate() {
        let world = world()
        let navigation = EditorVRNavigationController()
        #expect(navigation.update(in: world, keys: [.w], wheel: 1, textEditing: true) == .zero)
        #expect(navigation.update(in: world, keys: [.w]) == .zero)
        _ = navigation.update(in: world)
        #expect(navigation.update(in: world, keys: [.w]).z > 0)
        #expect(navigation.update(in: world, wheel: .nan) == .zero)
        world.insertResource(SpatialInput(grips: pinches(0)))
        #expect(navigation.update(in: world) == .zero)
        #expect(!navigation.isNavigating)
    }

    @Test("Tracking loss resets the two-hand baseline without accumulating keyboard movement")
    func trackingLoss() {
        let world = world()
        let navigation = EditorVRNavigationController()
        world.insertResource(SpatialInput(grips: pinches(0.4)))
        _ = navigation.update(in: world)
        world.removeResource(SpatialTrackingFrame.self)
        #expect(navigation.update(in: world, keys: [.w], wheel: 1) == .zero)
        #expect(!navigation.isNavigating)
        world.insertResource(SpatialTrackingFrame())
        world.insertResource(SpatialInput(grips: pinches(0.8)))
        #expect(navigation.update(in: world) == .zero)
    }

    @Test("Navigation leaves a real scene and history unchanged and panel focus blocks desktop input")
    func documentIsUnchanged() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World()))
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let workspace = EditorVRWorkspace(store: EditorProjectStore(storageURL: directory.appendingPathComponent("recent.json")))
        try workspace.createStarter(at: directory)
        let world = world()
        workspace.attachWorld(world)
        let content = workspace.document?.content
        let history = workspace.workbench.sceneUndoHistory
        #expect(workspace.navigate(world, keys: [.w], wheel: 1).z > 0)
        workspace.setTextInputFocus(true, host: "code")
        #expect(workspace.navigate(world, keys: [.w], wheel: 1) == .zero)
        workspace.setTextInputFocus(false, host: "code")
        workspace.setPanelHover(true, panel: .code)
        #expect(workspace.navigate(world, wheel: 1) == .zero)
        workspace.setPanelHover(false, panel: .code)
        world.insertResource(SpatialInput(grips: pinches(0.4)))
        _ = workspace.navigate(world)
        world.insertResource(SpatialInput(grips: pinches(0.5)))
        #expect(workspace.navigate(world).z > 0)
        #expect(workspace.document?.content == content)
        #expect(workspace.workbench.sceneUndoHistory == history)
    }
}
