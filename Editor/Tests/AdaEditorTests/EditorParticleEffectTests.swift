@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
@testable import AdaUI
import Foundation
import Testing
import Yams

@MainActor
@Suite("Particle FX editor", .serialized)
struct EditorParticleEffectTests {
    @Test("New-file template opens through the ordinary particle resource route")
    func template() throws {
        let kind = EditorNewFileKind.particleEffect
        let descriptor = try YAMLDecoder().decode(ParticleEffectDescriptor.self, from: kind.initialContent(fileName: "Flame.particles"))
        #expect(descriptor.emitters.first?.name == "Flame")
        #expect(kind.fileExtension == "particles")
        #expect(EditorViewModel.assetPreviewKind(for: .genericAsset, fileExtension: "particles") == .particleEffect)
        let authored = try YAMLDecoder().decode(ParticleEffectDescriptor.self, from: "emitters:\n  - name: Flame\n    gravity: [0, 15]\n")
        #expect(authored.emitters[0].gravity.y == 15)
    }

    @Test("Emitter edits, curves and Undo/Redo persist through real resource files")
    func authoring() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = EditorParticleEffectEditorModel(document: document(root))
        defer { model.cancelPreview() }
        #expect(model.error == nil)
        #expect(model.updateEmitter { $0.emissionRate = 40 })
        #expect(try read(root).emitters[0].emissionRate == 40)
        model.undo()
        #expect(try read(root).emitters[0].emissionRate == 80)
        model.redo()
        #expect(try read(root).emitters[0].emissionRate == 40)
        model.addEmitter()
        #expect(try read(root).emitters.count == 2)
        model.addCurveKey(\ParticleEmitterDescriptor.sizeCurve)
        #expect(try read(root).emitters[1].sizeCurve.keys.count == 3)
        model.moveCurveKey(\ParticleEmitterDescriptor.sizeCurve, index: 1, time: 0.7, value: 0.3)
        #expect(try read(root).emitters[1].sizeCurve.keys[1].time == 0.7)
        model.removeEmitter()
        #expect(try read(root).emitters.count == 1)
        let before = try Data(contentsOf: root.appendingPathComponent("Flame.particles"))
        #expect(!model.updateEmitter { $0.maxParticles = 0 })
        #expect(try Data(contentsOf: root.appendingPathComponent("Flame.particles")) == before)
    }

    @Test("External changes are preserved instead of overwritten")
    func externalChange() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = EditorParticleEffectEditorModel(document: document(root))
        defer { model.cancelPreview() }
        let url = root.appendingPathComponent("Flame.particles")
        let external = "emitters:\n  - name: External\n"
        try external.write(to: url, atomically: true, encoding: .utf8)
        #expect(!model.updateEmitter { $0.name = "Mine" })
        #expect(try String(contentsOf: url, encoding: .utf8) == external)
        model.reload()
        #expect(model.emitter.name == "External")
    }

    @Test("Saved scene references load the effect into a runtime emitter and reject escaping paths")
    func sceneRuntime() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Main.ascn")
        let payload = try EditorSceneFileLoader.resolvedComponentPayload(
            typeName: EditorBuiltInComponentType.particleEmitter,
            payload: ["effect": .string("@res://Flame.particles"), "isPaused": .bool(true)],
            sourceURL: source,
            resourceRootURL: root
        )
        let component = try #require(try EditorComponentRegistry.particleEmitterDescriptor.decode(payload) as? ParticleEmitter)
        #expect(component.isPaused)
        #expect(component.effect?.asset?.descriptor.emitters[0].name == "Flame")
        #expect(throws: (any Error).self) {
            try EditorSceneFileLoader.resolvedComponentPayload(
                typeName: EditorBuiltInComponentType.particleEmitter,
                payload: ["effect": .string("@res://../Outside.particles")],
                sourceURL: source,
                resourceRootURL: root
            )
        }
    }

    @Test("Live particle telemetry updates only its label and preserves the settings tree")
    func previewTelemetry() async throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "Particle UI test")))
        }
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let asset = document(root)
        let model = EditorParticleEffectEditorModel(document: asset)
        defer { model.cancelPreview() }
        let workbench = EditorWorkbenchViewModel(openDocuments: [.asset(asset)], activeDocumentID: asset.id)
        let container = UIContainerView(rootView: EditorParticleEffectAssetEditor(document: asset, model: model, workbench: workbench))
        container.frame = Rect(x: 0, y: 0, width: 1000, height: 700)
        container.layoutSubviews()
        for _ in 0..<20 { await Task.yield() }
        model.cancelPreview()
        container.layoutSubviews()

        let settings = try #require(container.viewTree.rootNode.findNodyByAccessibilityIdentifier("AdaEditor.ParticleFX.Field.Emission / sec"))
        let count = try #require(container.viewTree.rootNode.findNodyByAccessibilityIdentifier("AdaEditor.ParticleFX.Count"))
        let settingsAncestors = observationAncestors(settings).map { ($0, $0.contentObservationRevision) }
        let countContainer = try #require(observationAncestors(count).first)
        let countRevision = countContainer.contentObservationRevision
        var ancestor: ViewNode? = settings
        while let node = ancestor, !(node is DrawingGroupViewNode) { ancestor = node.parent }
        let settingsLayer = try #require(ancestor?.layer)
        settingsLayer.drawLayer(in: UIGraphicsContext())
        let layerRevision = settingsLayer.commandVersion
        #expect(!settingsAncestors.isEmpty)

        // One second of changing runtime telemetry must not rebuild the authoring form.
        for frame in 1...100 {
            model.previewStatistics.record(particleCount: frame, deltaTime: 0.01)
            for _ in 0..<3 { await Task.yield() }
            container.layoutSubviews()
        }
        for _ in 0..<20 { await Task.yield() }
        container.layoutSubviews()
        #expect(model.previewStatistics.particleCount >= 75)
        #expect((1...4).contains(countContainer.contentObservationRevision - countRevision))
        for (node, revision) in settingsAncestors {
            #expect(node.contentObservationRevision == revision)
        }
        #expect(container.viewTree.rootNode.findNodyByAccessibilityIdentifier("AdaEditor.ParticleFX.Field.Emission / sec") === settings)
        settingsLayer.drawLayer(in: UIGraphicsContext())
        #expect(settingsLayer.commandVersion == layerRevision)

        // An actual authored change must still invalidate the cached form.
        #expect(model.updateEmitter { $0.emissionRate = 123 })
        for _ in 0..<20 { await Task.yield() }
        container.layoutSubviews()
        settingsLayer.drawLayer(in: UIGraphicsContext())
        #expect(settingsLayer.commandVersion > layerRevision)
    }

    private func observationAncestors(_ node: ViewNode) -> [ViewContainerNode] {
        var result: [ViewContainerNode] = []
        var current: ViewNode? = node
        while let node = current {
            if let container = node as? ViewContainerNode { result.append(container) }
            current = node.parent
        }
        return result
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AdaParticlesEditor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try EditorNewFileKind.particleEffect.initialContent(fileName: "Flame.particles")
            .write(to: root.appendingPathComponent("Flame.particles"), atomically: true, encoding: .utf8)
        return root
    }

    private func read(_ root: URL) throws -> ParticleEffectDescriptor {
        try YAMLDecoder().decode(ParticleEffectDescriptor.self, from: Data(contentsOf: root.appendingPathComponent("Flame.particles")))
    }

    private func document(_ root: URL) -> EditorAssetDocument {
        .init(
            id: "particles",
            title: "Flame.particles",
            relativePath: "Assets/Flame.particles",
            absolutePath: root.appendingPathComponent("Flame.particles").path,
            assetReference: "@res://Flame.particles",
            kind: .particleEffect,
            fileExtension: "particles"
        )
    }
}
