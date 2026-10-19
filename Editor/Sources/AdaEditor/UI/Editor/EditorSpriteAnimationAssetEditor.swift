@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorSpriteAnimationAssetEditor: View {
    let document: EditorAssetDocument
    let model: EditorSpriteAnimationEditorModel
    let workbench: EditorWorkbenchViewModel
    @Environment(\.theme) private var theme
    @State private var sceneSelection = ""
    @State private var gridRow = "0"
    @State private var gridFrom = "0"
    @State private var gridThrough = "3"
    @State private var asepritePath = ""

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
                        inspector.frame(width: 320)
                    }
                    .frame(height: max(180, geometry.size.height - 76))
                }
                Text(model.error ?? model.status)
                    .font(.system(size: 11)).foregroundColor(model.error == nil ? theme.editorColors.muted : .red)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .padding(12)
        .accessibilityIdentifier("AdaEditor.SpriteAnimation.Editor")
        .onAppear { model.refreshPreview() }
        .onDisappear { model.cancelPreview() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(L10n.text("Sprite Animation")).font(.system(size: 14, weight: .bold))
            Spacer()
            Button(L10n.text("Undo")) { model.undo() }.disabled(!model.canUndo)
            Button(L10n.text("Redo")) { model.redo() }.disabled(!model.canRedo)
            Button(L10n.text("Reload")) { model.reload() }
        }
        .buttonStyle(DefaultButtonStyle()).foregroundColor(theme.editorColors.text)
        .font(.system(size: 12))
        .frame(height: 32)
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 8) {
            EditorSpriteAnimationViewport(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 12) {
                Button(model.isPlaying ? L10n.text("Pause") : L10n.text("Play")) { model.isPlaying.toggle() }
                    .accessibilityIdentifier("AdaEditor.SpriteAnimation.Play")
                Button(L10n.text("Restart")) { model.restartCount &+= 1 }
                    .accessibilityIdentifier("AdaEditor.SpriteAnimation.Restart")
                Spacer()
                EditorSpriteAnimationLiveFrame(statistics: model.previewStatistics)
            }
            .buttonStyle(DefaultButtonStyle()).foregroundColor(theme.editorColors.text)
            .font(.system(size: 12))
            if !targetScenes.isEmpty {
                HStack {
                    EditorEnumField(cases: targetScenes.map(\.relativePath), selection: Binding(
                        get: { sceneSelection.isEmpty ? targetScenes.first?.relativePath ?? "" : sceneSelection },
                        set: { sceneSelection = $0 }
                    ), accessibilityID: "AdaEditor.SpriteAnimation.Scene")
                    Button(L10n.text("Add to Scene")) {
                        let scene = targetScenes.first { $0.relativePath == sceneSelection } ?? targetScenes.first
                        if let scene { workbench.addSpriteAnimation(document, to: scene.id) }
                    }
                    .buttonStyle(DefaultButtonStyle()).disabled(document.assetReference == nil || model.previewSet == nil)
                    .foregroundColor(theme.editorColors.blue)
                    .accessibilityIdentifier("AdaEditor.SpriteAnimation.AddToScene")
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

    // MARK: - Inspector

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                sheetSection
                Divider()
                clipSection
                if let clip = model.clip {
                    framesSection(clip)
                }
                Divider()
                asepriteSection
            }
            .padding(8)
        }
        .font(.system(size: 12)).foregroundColor(theme.editorColors.text)
        .background(RoundedRectangleShape(cornerRadius: 8).fill(theme.editorColors.surface))
    }

    private var sheetSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("Image")).font(.system(size: 11, weight: .bold))
            row("Path") {
                EditorUIDesignerField(placeholder: "Sheet.png, relative to this file", text: Binding(
                    get: { model.descriptor.image }, set: { value in model.updateDescriptor { $0.image = value } }
                )).accessibilityIdentifier("AdaEditor.SpriteAnimation.Image")
            }
            row("Cell Width") { integerField(model.descriptor.cellSize?.width) { size($0, nil) } }
            row("Cell Height") { integerField(model.descriptor.cellSize?.height) { size(nil, $0) } }
            row("Filter") {
                EditorEnumField(
                    cases: SpriteAnimationSetDescriptor.Filter.allCases.map(\.rawValue),
                    selection: Binding(
                        get: { model.descriptor.filter.rawValue },
                        set: { value in
                            if let filter = SpriteAnimationSetDescriptor.Filter(rawValue: value) { model.updateDescriptor { $0.filter = filter } }
                        }
                    ),
                    accessibilityID: "AdaEditor.SpriteAnimation.Filter"
                )
            }
        }
    }

    private var clipSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("Clips")).font(.system(size: 11, weight: .bold))
            if !model.descriptor.clips.isEmpty {
                EditorEnumField(
                    cases: model.descriptor.clips.indices.map { "\($0 + 1): \(model.descriptor.clips[$0].name)" },
                    selection: Binding(
                        get: { model.clip.map { "\(model.selectedClip + 1): \($0.name)" } ?? "" },
                        set: { if let number = Int($0.split(separator: ":").first ?? "") { model.selectedClip = number - 1 } }
                    ),
                    accessibilityID: "AdaEditor.SpriteAnimation.Clip"
                )
                .drawingGroup()
            }
            HStack {
                Button(L10n.text("Add Clip")) { model.addClip() }
                    .disabled(model.descriptor.clips.count >= EditorSpriteAnimationEditorModel.maximumClips)
                    .accessibilityIdentifier("AdaEditor.SpriteAnimation.AddClip")
                Spacer()
                Button(L10n.text("Remove")) { model.removeClip() }.disabled(model.clip == nil).foregroundColor(.red)
            }.buttonStyle(DefaultButtonStyle())
            if let clip = model.clip {
                row("Name") {
                    EditorUIDesignerField(placeholder: "Name", text: Binding(
                        get: { clip.name }, set: { value in model.updateClip { $0.name = value } }
                    )).accessibilityIdentifier("AdaEditor.SpriteAnimation.ClipName")
                }
                row("Frames / sec") {
                    EditorUIDesignerField(placeholder: "12", text: Binding(
                        get: { String(format: "%.4g", clip.framesPerSecond) },
                        set: { if let value = Float($0), value.isFinite, value > 0 { model.updateClip { $0.framesPerSecond = value } } }
                    )).accessibilityIdentifier("AdaEditor.SpriteAnimation.FPS")
                }
                row("Playback") {
                    EditorEnumField(
                        cases: SpriteAnimationPlaybackMode.allCases.map(\.rawValue),
                        selection: Binding(
                            get: { clip.playbackMode.rawValue },
                            set: { value in
                                if let mode = SpriteAnimationPlaybackMode(rawValue: value) { model.updateClip { $0.playbackMode = mode } }
                            }
                        ),
                        accessibilityID: "AdaEditor.SpriteAnimation.Playback"
                    )
                }
            }
        }
    }

    private func framesSection(_ clip: SpriteAnimationClip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("Frames")).font(.system(size: 11, weight: .bold))
            HStack(spacing: 4) {
                EditorUIDesignerField(placeholder: "Row", text: $gridRow).frame(width: 48)
                EditorUIDesignerField(placeholder: "From", text: $gridFrom).frame(width: 48)
                EditorUIDesignerField(placeholder: "To", text: $gridThrough).frame(width: 48)
                Button(L10n.text("Add Row Frames")) {
                    if let row = Int(gridRow), let from = Int(gridFrom), let through = Int(gridThrough) {
                        model.addGridFrames(row: row, from: from, through: through)
                    }
                }
                .buttonStyle(DefaultButtonStyle())
                .accessibilityIdentifier("AdaEditor.SpriteAnimation.AddFrames")
            }
            ForEach(clip.frames.indices, id: \.self) { index in
                frameRow(index, clip.frames[index])
            }
        }
    }

    private func frameRow(_ index: Int, _ frame: SpriteAnimationFrame) -> some View {
        HStack(spacing: 4) {
            Text("\(index + 1)").frame(width: 24, alignment: .leading)
            Text(Self.sourceSummary(frame)).font(.system(size: 10)).frame(width: 78, alignment: .leading)
            EditorUIDesignerField(placeholder: "1", text: Binding(
                get: { String(format: "%.3g", frame.duration) },
                set: { if let value = Float($0), value.isFinite, value >= 0 { model.updateFrame(at: index) { $0.duration = value } } }
            )).frame(width: 44)
            EditorUIDesignerField(placeholder: "Marker", text: Binding(
                get: { frame.marker ?? "" },
                set: { value in model.updateFrame(at: index) { $0.marker = value.isEmpty ? nil : value } }
            ))
            Button("\u{2191}") { model.moveFrame(at: index, by: -1) }.disabled(index == 0)
            Button("\u{2193}") { model.moveFrame(at: index, by: 1) }
            Button("\u{00D7}") { model.removeFrame(at: index) }.foregroundColor(.red)
        }
        .buttonStyle(DefaultButtonStyle())
        .drawingGroup()
    }

    private var asepriteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("Import from Aseprite")).font(.system(size: 11, weight: .bold))
            Text(L10n.text("Export the sheet with Trim off and a JSON array. Replaces the image and clips."))
                .font(.system(size: 10)).foregroundColor(theme.editorColors.muted)
            EditorUIDesignerField(placeholder: "hero.json, relative to this file", text: $asepritePath)
                .accessibilityIdentifier("AdaEditor.SpriteAnimation.AsepritePath")
            Button(L10n.text("Import")) { model.importAseprite(from: asepritePath) }
                .buttonStyle(DefaultButtonStyle())
                .accessibilityIdentifier("AdaEditor.SpriteAnimation.Import")
        }
    }

    // MARK: - Helpers

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        let field = content()
        return HStack {
            Text(L10n.tr(title)).frame(width: 90, alignment: .leading)
            field
        }
        .drawingGroup()
    }

    private func integerField(_ value: Int?, set: @escaping (Int) -> Void) -> some View {
        EditorUIDesignerField(placeholder: "Whole image", text: Binding(
            get: { value.map(String.init) ?? "" }, set: { if let number = Int($0), number > 0 { set(number) } }
        ))
    }

    /// Cell size is edited one axis at a time; the other axis keeps its value or starts from the image-sized default.
    private func size(_ width: Int?, _ height: Int?) {
        model.updateDescriptor {
            let current = $0.cellSize ?? SizeInt(width: width ?? height ?? 16, height: height ?? width ?? 16)
            $0.cellSize = SizeInt(width: width ?? current.width, height: height ?? current.height)
        }
    }

    static func sourceSummary(_ frame: SpriteAnimationFrame) -> String {
        if let region = frame.region {
            return "\(region.origin.x),\(region.origin.y) \(region.size.width)×\(region.size.height)"
        }
        if let cell = frame.atlasCoordinates { return "cell \(cell.x),\(cell.y)" }
        return "—"
    }
}

struct EditorSpriteAnimationLiveFrame: View {
    let statistics: EditorSpriteAnimationPreviewStatistics

    var body: some View {
        Text(statistics.frameText)
            .font(.system(size: 11))
            .frame(width: 112, alignment: .trailing)
            .accessibilityIdentifier("AdaEditor.SpriteAnimation.Frame")
    }
}

private struct EditorSpriteAnimationViewport: View {
    let model: EditorSpriteAnimationEditorModel
    @State private var driver = EditorSpriteAnimationPreviewDriver()

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
            app.main.spawn(EditorSpriteAnimationPreviewDriver.entityName) { Transform(); Sprite(); SpriteAnimator() }
        }, updateContent: { world, deltaTime in
            driver.update(world: world, model: model, deltaTime: Double(deltaTime))
        })
        .background(Color.fromHex(0x20242B))
        .mask(RoundedRectangleShape(cornerRadius: 8))
        .accessibilityIdentifier("AdaEditor.SpriteAnimation.Viewport")
    }
}
