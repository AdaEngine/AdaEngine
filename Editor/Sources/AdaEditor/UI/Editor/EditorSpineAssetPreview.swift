import AdaEngine
import AdaSpine
import Foundation
import Math
import Observation

@Observable
@MainActor
final class EditorSpinePreviewModel {
    var skeleton: SpineSkeleton?
    var error: String?
    var animation = ""
    var skin = ""
    var isPlaying = true
    var showBones = true
    var speed: Float = 1
    @ObservationIgnored var viewportSize = Size(width: 640, height: 480)
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var entityID: Entity.ID?
    @ObservationIgnored private var applied: SpineSource?
    @ObservationIgnored private var loadedPath: String?

    func load(path: String?) {
        if loadedPath == path, skeleton != nil { return }
        loadedPath = path
        task?.cancel()
        skeleton = nil
        error = nil
        task = Task { [weak self] in
            do {
                guard let path else { throw AssetError.message("Skeleton file is unavailable.") }
                let handle = try await AssetsManager.load(SpineSkeleton.self, at: path)
                try Task.checkCancellation()
                guard let skeleton = handle.asset else { throw AssetError.message("Skeleton has not loaded.") }
                self?.animation = skeleton.animationNames.contains("walk") ? "walk" : skeleton.animationNames.first ?? ""
                self?.skeleton = skeleton
            } catch is CancellationError { return }
            catch { self?.error = error.localizedDescription }
        }
    }

    func cancel() { task?.cancel() }

    func attach(to world: World) {
        let entity = world.spawn("Spine Preview") { Transform() }
        entityID = entity.id
        applied = nil
        update(in: world)
    }

    func update(in world: World) {
        guard let skeleton, let entityID, let entity = world.getEntityByID(entityID) else { return }
        let reference = SpineSource(animation: animation, skin: skin, autoplay: isPlaying, speed: speed, showBones: showBones)
        if applied != reference {
            do {
                if applied == nil || applied?.animation != animation || applied?.skin != skin {
                    try reference.instantiate(skeleton, on: entity)
                } else if var component = entity.components[SpineAnimation.self] {
                    component.isPaused = !isPlaying
                    component.speed = speed
                    entity.components[SpineAnimation.self] = component
                    entity.components[SpineDebugBones.self] = showBones ? SpineDebugBones() : nil
                }
                entity.components[SpineSource.self] = reference
                entity.components[SpineSourceState.self] = .init(reference: reference)
                applied = reference
                error = nil
            } catch { self.error = error.localizedDescription }
        }
        guard let component = entity.components[SpineAnimation.self],
              let cameraEntity = world.getEntities().first(where: { $0.components[Camera.self] != nil }),
              var camera = cameraEntity.components[Camera.self] else { return }
        let points = component.player.snapshot().flatMap(\.vertices)
        guard let first = points.first else { return }
        var minimum = Vector2(first.x, first.y)
        var maximum = minimum
        for point in points {
            minimum.x = min(minimum.x, point.x); minimum.y = min(minimum.y, point.y)
            maximum.x = max(maximum.x, point.x); maximum.y = max(maximum.y, point.y)
        }
        camera.projection = .custom(EditorSpinePreviewProjection(minimum: minimum, maximum: maximum, size: viewportSize))
        camera.backgroundColor = Color(0.035, 0.055, 0.1, 1)
        cameraEntity.components[Camera.self] = camera
        cameraEntity.components[CameraRenderGraph.self] = CameraRenderGraph(subgraphLabel: .main2D, inputSlot: "view")
    }
}

private struct EditorSpinePreviewProjection: CameraProjection {
    var minimum: Vector2
    var maximum: Vector2
    var size: Size
    var near: Float { -1 }
    var far: Float { 1000 }
    func makeClipView() -> Transform3D {
        let aspect = max(0.1, size.width / max(1, size.height))
        let height = max(1, max(maximum.y - minimum.y, (maximum.x - minimum.x) / aspect)) * 1.18
        let center = (minimum + maximum) / 2
        return Transform3D(scale: [2 / (height * aspect), 2 / height, 0.001]) * Transform3D(translation: [-center.x, -center.y, 0])
    }
    mutating func updateView(width: Float, height: Float) {}
}

struct EditorSpineAssetPreview: View {
    let document: EditorAssetDocument
    let workbench: EditorWorkbenchViewModel
    @State private var model = EditorSpinePreviewModel()
    @State private var showsScenes = false
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let _ = model.viewportSize = Size(width: geometry.size.width, height: max(180, geometry.size.height - 118))
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(document.title).font(.system(size: 14, weight: .bold)).foregroundColor(theme.editorColors.text)
                    Spacer()
                    Button("Add to Scene…") { showsScenes.toggle() }
                        .disabled(model.skeleton == nil || targetScenes.isEmpty || document.assetReference == nil)
                        .accessibilityIdentifier("AdaEditor.SpinePreview.AddToScene")
                }
                if showsScenes {
                    ForEach(targetScenes, id: \.id) { scene in
                        Button(scene.relativePath) {
                            workbench.addSpineAsset(document, to: scene.id, animation: model.animation, skin: model.skin, showBones: model.showBones)
                            showsScenes = false
                        }
                        .accessibilityIdentifier("AdaEditor.SpinePreview.Scene.\(scene.id)")
                    }
                }
                ZStack {
                    RectangleShape().fill(Color(0.035, 0.055, 0.1, 1))
                    if let error = model.error { Text(error).foregroundColor(.red).padding(16) }
                    else if model.skeleton != nil {
                        SceneView(make: { app in
                            app.addPlugin(TransformPlugin()).addPlugin(InputPlugin(actions: []))
                                .addPlugin(RenderWorldPlugin()).addPlugin(CameraPlugin())
                                .addPlugin(AssetsPlugin(filePath: #filePath)).addPlugin(VisibilityPlugin())
                                .addPlugin(Core2DPlugin()).addPlugin(UpscalePlugin()).addPlugin(SpinePlugin())
                            model.attach(to: app.main)
                        }, updateContent: { world, _ in model.update(in: world) })
                        .accessibilityIdentifier("AdaEditor.SpinePreview.Viewport")
                    } else { Text("Loading Spine skeleton…").foregroundColor(theme.editorColors.muted) }
                }
                .frame(height: max(180, geometry.size.height - (showsScenes ? 200 : 118)))
                HStack(spacing: 8) {
                    EditorEnumField(cases: [""] + (model.skeleton?.animationNames ?? []),
                        selection: Binding(get: { model.animation }, set: { model.animation = $0 }), accessibilityID: "AdaEditor.SpinePreview.Animation")
                        .frame(maxWidth: 220)
                    Button(model.isPlaying ? "Pause" : "Play") { model.isPlaying.toggle() }
                        .accessibilityIdentifier("AdaEditor.SpinePreview.Play")
                    Button(model.showBones ? "Hide bones" : "Show bones") { model.showBones.toggle() }
                        .accessibilityIdentifier("AdaEditor.SpinePreview.Bones")
                    Spacer()
                }
                HStack(spacing: 8) {
                    Text("Skin").font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
                    EditorEnumField(cases: [""] + (model.skeleton?.skinNames ?? []),
                        selection: Binding(get: { model.skin }, set: { model.skin = $0 }), accessibilityID: "AdaEditor.SpinePreview.Skin")
                        .frame(maxWidth: 220)
                    Text("Spine 4.2").font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
                    Spacer()
                }
            }
        }
        .padding(16)
        .accessibilityIdentifier("AdaEditor.SpinePreview")
        .onAppear { model.load(path: document.absolutePath) }
        .onDisappear { model.cancel() }
    }

    private var targetScenes: [EditorSceneDocument] {
        workbench.openDocuments.compactMap {
            guard case let .scene(scene) = $0, !scene.isReadOnly, scene.sceneModel != nil else { return nil }
            return scene
        }
    }
}

extension EditorWorkbenchViewModel {
    @discardableResult
    func addSpineAsset(_ asset: EditorAssetDocument, to documentID: String, animation: String = "", skin: String = "", showBones: Bool = true) -> Bool {
        guard asset.kind == .spine2D, let reference = asset.assetReference,
              let document = sceneDocument(id: documentID), !document.isReadOnly, document.sceneModel != nil else { return false }
        selectDocument(id: documentID)
        updateSceneModelDocument(id: documentID, status: "Spine character added") { scene in
            let entity = scene.addEntity(template: .spine2D, parentID: scene.editor?.selectedEntity)
            guard let index = scene.entities.firstIndex(where: { $0.id == entity.id }) else { return }
            scene.entities[index].name = URL(fileURLWithPath: asset.title).deletingPathExtension().lastPathComponent
            scene.entities[index].components[EditorBuiltInComponentType.spineSource] = [
                "source": .string(reference), "animation": .string(animation), "skin": .string(skin),
                "autoplay": .bool(true), "repeats": .bool(true), "speed": .double(1), "showBones": .bool(showBones),
            ]
        }
        return true
    }
}
