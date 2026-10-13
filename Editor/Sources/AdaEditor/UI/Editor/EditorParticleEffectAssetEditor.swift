@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorParticleEffectAssetEditor: View {
    let document: EditorAssetDocument
    let model: EditorParticleEffectEditorModel
    let workbench: EditorWorkbenchViewModel
    @Environment(\.theme) private var theme
    @State private var sceneSelection = ""

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                header
                if geometry.size.width < 550 {
                    preview.frame(height: max(150, geometry.size.height * 0.4))
                    inspector.frame(height: max(100, geometry.size.height - max(150, geometry.size.height * 0.4) - 84))
                } else {
                    HStack(spacing: 12) {
                        preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                        inspector.frame(width: 300)
                    }
                    .frame(height: max(180, geometry.size.height - 76))
                }
                Text(model.error ?? model.status)
                    .font(.system(size: 11)).foregroundColor(model.error == nil ? theme.editorColors.muted : .red)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .padding(12)
        .accessibilityIdentifier("AdaEditor.ParticleFX.Editor")
        .onAppear { model.refreshPreview() }
        .onDisappear { model.cancelPreview() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Particle FX").font(.system(size: 14, weight: .bold))
            Spacer()
            Button("Undo") { model.undo() }.disabled(!model.canUndo)
            Button("Redo") { model.redo() }.disabled(!model.canRedo)
            Button("Reload") { model.reload() }
        }
        .buttonStyle(DefaultButtonStyle()).foregroundColor(theme.editorColors.text)
        .font(.system(size: 12))
        .frame(height: 32)
    }

    private var preview: some View {
        VStack(spacing: 8) {
            EditorParticleEffectViewport(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 12) {
                Button(model.isPlaying ? "Pause" : "Play") { model.isPlaying.toggle() }
                    .accessibilityIdentifier("AdaEditor.ParticleFX.Play")
                Button("Restart") { model.restartCount &+= 1 }
                    .accessibilityIdentifier("AdaEditor.ParticleFX.Restart")
                Spacer()
                EditorParticleLiveCount(statistics: model.previewStatistics)
            }
            .buttonStyle(DefaultButtonStyle()).foregroundColor(theme.editorColors.text)
            .font(.system(size: 12))
            if !targetScenes.isEmpty {
                HStack {
                    EditorEnumField(cases: targetScenes.map(\.relativePath), selection: Binding(
                        get: { sceneSelection.isEmpty ? targetScenes.first?.relativePath ?? "" : sceneSelection },
                        set: { sceneSelection = $0 }
                    ), accessibilityID: "AdaEditor.ParticleFX.Scene")
                    Button("Add to Scene") {
                        let scene = targetScenes.first { $0.relativePath == sceneSelection } ?? targetScenes.first
                        if let scene { workbench.addParticleEffect(document, to: scene.id) }
                    }
                    .buttonStyle(DefaultButtonStyle()).disabled(document.assetReference == nil || model.previewEffect == nil)
                    .foregroundColor(theme.editorColors.blue)
                    .accessibilityIdentifier("AdaEditor.ParticleFX.AddToScene")
                }
                .font(.system(size: 12))
            }
        }
    }

    private var targetScenes: [EditorSceneDocument] {
        workbench.openDocuments.compactMap {
            guard case let .scene(scene) = $0, !scene.isReadOnly, scene.sceneModel != nil else { return nil }
            return scene
        }
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                EditorEnumField(cases: model.descriptor.emitters.indices.map { "\($0 + 1): \(model.descriptor.emitters[$0].name)" }, selection: Binding(
                    get: { "\(model.selectedEmitter + 1): \(model.emitter.name)" },
                    set: { if let number = Int($0.split(separator: ":").first ?? "") { model.selectedEmitter = number - 1 } }
                ), accessibilityID: "AdaEditor.ParticleFX.Emitter")
                .drawingGroup()
                HStack {
                    Button("Add Emitter") { model.addEmitter() }.disabled(model.descriptor.emitters.count >= 16)
                    Spacer()
                    Button("Remove") { model.removeEmitter() }.disabled(model.descriptor.emitters.count <= 1).foregroundColor(.red)
                }.buttonStyle(DefaultButtonStyle())
                text("Name", \ParticleEmitterDescriptor.name)
                text("Texture", \ParticleEmitterDescriptor.texture)
                choice("Shape", cases: ParticleEmitterDescriptor.Shape.allCases.map(\.rawValue), get: { model.emitter.shape.rawValue }) {
                    if let shape = ParticleEmitterDescriptor.Shape(rawValue: $0) { model.updateEmitter { $0.shape = shape } }
                }
                choice("Space", cases: ParticleEmitterDescriptor.Space.allCases.map(\.rawValue), get: { model.emitter.space.rawValue }) {
                    if let space = ParticleEmitterDescriptor.Space(rawValue: $0) { model.updateEmitter { $0.space = space } }
                }
                number("Offset X", get: { model.emitter.offset.x }) { value in model.updateEmitter { $0.offset.x = value } }
                number("Offset Y", get: { model.emitter.offset.y }) { value in model.updateEmitter { $0.offset.y = value } }
                if model.emitter.shape == .circle { scalar("Radius", \ParticleEmitterDescriptor.radius) }
                if model.emitter.shape == .box {
                    number("Box Width", get: { model.emitter.boxSize.x }) { value in model.updateEmitter { $0.boxSize.x = value } }
                    number("Box Height", get: { model.emitter.boxSize.y }) { value in model.updateEmitter { $0.boxSize.y = value } }
                }
                integer("Max Particles", \ParticleEmitterDescriptor.maxParticles)
                scalar("Emission / sec", \ParticleEmitterDescriptor.emissionRate)
                integer("Burst", \ParticleEmitterDescriptor.burstCount)
                scalar("Duration", \ParticleEmitterDescriptor.duration)
                Toggle("Loop", isOn: Binding(get: { model.emitter.loops }, set: { value in model.updateEmitter { $0.loops = value } }))
                scalar("Lifetime Min", \ParticleEmitterDescriptor.lifetimeMin)
                scalar("Lifetime Max", \ParticleEmitterDescriptor.lifetimeMax)
                scalar("Speed Min", \ParticleEmitterDescriptor.speedMin)
                scalar("Speed Max", \ParticleEmitterDescriptor.speedMax)
                scalar("Direction °", \ParticleEmitterDescriptor.direction)
                scalar("Spread °", \ParticleEmitterDescriptor.spread)
                number("Gravity X", get: { model.emitter.gravity.x }) { value in model.updateEmitter { $0.gravity.x = value } }
                number("Gravity Y", get: { model.emitter.gravity.y }) { value in model.updateEmitter { $0.gravity.y = value } }
                scalar("Size Min", \ParticleEmitterDescriptor.sizeMin)
                scalar("Size Max", \ParticleEmitterDescriptor.sizeMax)
                scalar("Rotation °/sec", \ParticleEmitterDescriptor.angularVelocity)
                color("Start Color", \ParticleEmitterDescriptor.startColor)
                color("End Color", \ParticleEmitterDescriptor.endColor)
                EditorParticleCurveEditor(title: "Size over lifetime", path: \ParticleEmitterDescriptor.sizeCurve, model: model)
                EditorParticleCurveEditor(title: "Opacity over lifetime", path: \ParticleEmitterDescriptor.opacityCurve, model: model)
            }
            .padding(8)
        }
        .font(.system(size: 12)).foregroundColor(theme.editorColors.text)
        .background(RoundedRectangleShape(cornerRadius: 8).fill(theme.editorColors.surface))
    }

    private func text(_ title: String, _ path: WritableKeyPath<ParticleEmitterDescriptor, String>) -> some View {
        HStack {
            Text(title).frame(width: 100, alignment: .leading)
            EditorUIDesignerField(placeholder: title, text: Binding(
                get: { model.emitter[keyPath: path] }, set: { value in model.updateEmitter { $0[keyPath: path] = value } }
            ))
        }
        .drawingGroup()
    }

    private func scalar(_ title: String, _ path: WritableKeyPath<ParticleEmitterDescriptor, Float>) -> some View {
        number(title, get: { model.emitter[keyPath: path] }) { value in model.updateEmitter { $0[keyPath: path] = value } }
    }

    private func number(_ title: String, get: @escaping () -> Float, set: @escaping (Float) -> Void) -> some View {
        HStack {
            Text(title).frame(width: 100, alignment: .leading)
            EditorUIDesignerField(placeholder: title, text: Binding(
                get: { String(format: "%.3g", get()) }, set: { if let value = Float($0), value.isFinite { set(value) } }
            )).accessibilityIdentifier("AdaEditor.ParticleFX.Field.\(title)")
        }
        .drawingGroup()
    }

    private func integer(_ title: String, _ path: WritableKeyPath<ParticleEmitterDescriptor, Int>) -> some View {
        HStack {
            Text(title).frame(width: 100, alignment: .leading)
            EditorUIDesignerField(placeholder: title, text: Binding(
                get: { String(model.emitter[keyPath: path]) }, set: { if let value = Int($0) { model.updateEmitter { $0[keyPath: path] = value } } }
            ))
        }
        .drawingGroup()
    }

    private func choice(_ title: String, cases: [String], get: @escaping () -> String, set: @escaping (String) -> Void) -> some View {
        HStack {
            Text(title).frame(width: 100, alignment: .leading)
            EditorEnumField(cases: cases, selection: Binding(get: get, set: set), accessibilityID: "AdaEditor.ParticleFX.\(title)")
        }
        .drawingGroup()
    }

    private func color(_ title: String, _ path: WritableKeyPath<ParticleEmitterDescriptor, Color>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            EditorUIColorField(value: colorHex(model.emitter[keyPath: path])) { string in
                if let color = EditorUIColorField.color(string) { model.updateEmitter { $0[keyPath: path] = color } }
            }
        }
        .drawingGroup()
    }

    private func colorHex(_ color: Color) -> String {
        EditorInspectorColorValue(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha).hexString
    }
}

private struct EditorParticleEffectViewport: View {
    let model: EditorParticleEffectEditorModel
    @State private var driver = EditorParticlePreviewDriver()

    var body: some View {
        SceneView(make: { app in
            app.addPlugin(TransformPlugin())
                .addPlugin(InputPlugin(actions: []))
                .addPlugin(RenderWorldPlugin())
                .addPlugin(CameraPlugin())
                .addPlugin(VisibilityPlugin())
                .addPlugin(SpritePlugin())
                .addPlugin(Core2DPlugin())
                .addPlugin(UpscalePlugin())
            app.main.spawn("Particle preview") { Transform(); ParticleEmitter() }
        }, updateContent: { world, deltaTime in
            driver.update(world: world, model: model, deltaTime: Double(deltaTime))
        })
        .background(Color.fromHex(0x20242B))
        .mask(RoundedRectangleShape(cornerRadius: 8))
        .accessibilityIdentifier("AdaEditor.ParticleFX.Viewport")
    }
}
