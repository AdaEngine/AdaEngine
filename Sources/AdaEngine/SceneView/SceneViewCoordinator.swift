//
//  SceneViewCoordinator.swift
//  AdaEngine
//
//  Created by AdaEngine on 04.04.2026.
//

import AdaApp
import AdaAssets
import AdaECS
@_spi(Internal) import AdaInput
@_spi(Internal) import AdaRender
import AdaScene
import AdaSprite
import AdaText
import AdaTilemap
import AdaTransform
import AdaPhysics
import AdaCorePipelines
import AdaUI
import AdaUtils
import Math

@MainActor
final class SceneViewCoordinator: OffscreenViewportDelegate {
    private(set) var appWorlds: AppWorlds?
    private var cameraEntity: Entity?
    private(set) var renderTexture: Texture2D?

    private var isBootstrapping = false
    private var hasCalledSetup = false
    /// When true, this coordinator's ``AppWorlds`` is a subworld of ``AppWorldsSession/current`` and is updated by the host ``AppWorlds/update()`` loop (no separate ``tick`` work).
    private var isHostedSubworld = false
    /// Fallback when no host session exists (e.g. unusual test harnesses).
    private var standaloneTickInFlight = false

    private let hostSubworldName: AppWorldName
    private var currentSize: SizeInt = .zero
    private var scaleFactor: Float = 1

    private let filePath: StaticString
    private let setupClosure: @MainActor (World) -> Void

    init(filePath: StaticString, setup: @escaping @MainActor (World) -> Void) {
        self.filePath = filePath
        self.setupClosure = setup
        self.hostSubworldName = AppWorldName(rawValue: "SceneView.\(UUID().uuidString)")
    }

    deinit {
        let name = hostSubworldName
        Task { @MainActor in
            AppWorldsSession.current?.removeSubworld(by: name)
        }
    }

    // MARK: - OffscreenViewportDelegate

    func bootstrapIfNeeded() {
        guard appWorlds == nil && !isBootstrapping else { return }
        isBootstrapping = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            let app = self.buildAppWorlds()
            if let host = AppWorldsSession.current {
                host.addSubworld(app, by: self.hostSubworldName)
                self.isHostedSubworld = true
            } else {
                self.isHostedSubworld = false
            }
            try? await app.build()
            self.appWorlds = app
            self.isBootstrapping = false
            self.finalizeSetupIfReady()
        }
    }

    func updateSize(_ size: SizeInt, scaleFactor: Float) {
        guard size.width > 0 && size.height > 0 else { return }
        guard size != currentSize || scaleFactor != self.scaleFactor else { return }
        currentSize = size
        self.scaleFactor = scaleFactor

        let texture = RenderTexture(
            size: size,
            scaleFactor: scaleFactor,
            format: .bgra8,
            debugLabel: "SceneView_RenderTarget"
        )
        self.renderTexture = texture

        if let entity = cameraEntity, let app = appWorlds {
            updateCameraTarget(app: app, entity: entity, texture: texture)
        } else {
            finalizeSetupIfReady()
        }
    }

    func tick(_ deltaTime: AdaUtils.TimeInterval) {
        guard appWorlds != nil && hasCalledSetup else {
            return
        }
        if isHostedSubworld {
            return
        }
        standaloneTick(deltaTime)
    }

    func receiveInputEvent(_ event: any InputEvent) {
        guard let app = appWorlds else { return }
        let input = app.main.getRefResource(Input.self)
        input.wrappedValue.receiveEvent(event)
    }

    func updateMousePosition(_ position: Point) {
        guard let app = appWorlds else { return }
        let input = app.main.getRefResource(Input.self)
        input.wrappedValue.mousePosition = position
    }

    // MARK: - Private

    private func standaloneTick(_ deltaTime: AdaUtils.TimeInterval) {
        guard !standaloneTickInFlight else { return }
        standaloneTickInFlight = true
        Task { @MainActor [weak self] in
            defer { self?.standaloneTickInFlight = false }
            guard let self, let app = self.appWorlds else { return }
            app.main.insertResource(DeltaTime(deltaTime: deltaTime))
            try? await app.update()
        }
    }

    private func finalizeSetupIfReady() {
        guard let app = appWorlds,
              currentSize.width > 0 && currentSize.height > 0,
              !hasCalledSetup else { return }

        if renderTexture == nil {
            let texture = RenderTexture(
                size: currentSize,
                scaleFactor: scaleFactor,
                format: .bgra8,
                debugLabel: "SceneView_RenderTarget"
            )
            self.renderTexture = texture
        }

        spawnCamera(in: app)
        setupClosure(app.main)
        hasCalledSetup = true
    }

    private func spawnCamera(in app: AppWorlds) {
        guard let texture = renderTexture as? RenderTexture else {
            return
        }

        let logicalSize = Size(
            width: Float(currentSize.width) / scaleFactor,
            height: Float(currentSize.height) / scaleFactor
        )
        let physicalSize = Size(
            width: Float(currentSize.width),
            height: Float(currentSize.height)
        )

        var camera = Camera(renderTarget: texture)
        camera.viewport.rect = Rect(origin: .zero, size: physicalSize)
        camera.logicalViewport.rect = Rect(origin: .zero, size: logicalSize)

        cameraEntity = app.main.spawn("SceneView_Camera") {
            camera
            GlobalViewUniform()
            VisibleEntities()
            Transform()
            Visibility.visible
            CameraRenderGraph(
                subgraphLabel: .main2D,
                inputSlot: Main2DRenderNode.InputNode.view
            )
        }
    }

    private func updateCameraTarget(app: AppWorlds, entity: Entity, texture: RenderTexture) {
        let logicalSize = Size(
            width: Float(currentSize.width) / scaleFactor,
            height: Float(currentSize.height) / scaleFactor
        )
        let physicalSize = Size(
            width: Float(currentSize.width),
            height: Float(currentSize.height)
        )

        if var camera: Camera = entity.components[Camera.self] {
            camera.renderTarget = .texture(AssetHandle(texture))
            camera.viewport.rect = Rect(origin: .zero, size: physicalSize)
            camera.logicalViewport.rect = Rect(origin: .zero, size: logicalSize)
            entity.components += camera
        }
    }

    private func buildAppWorlds() -> AppWorlds {
        let world = World(name: "SceneView")
        let app = AppWorlds(main: world)

        MainSchedulerPlugin().setup(in: app)

        app.addPlugin(TransformPlugin())
        app.addPlugin(InputPlugin())
        app.addPlugin(RenderWorldPlugin())
        app.addPlugin(EventsPlugin())
        app.addPlugin(CameraPlugin())
        app.addPlugin(AssetsPlugin(filePath: filePath))
        app.addPlugin(VisibilityPlugin())
        app.addPlugin(SpritePlugin())
        app.addPlugin(Mesh2DPlugin())
        app.addPlugin(TextPlugin())
        app.addPlugin(ScenePlugin())
        app.addPlugin(ScriptableObjectPlugin())
        app.addPlugin(Physics2DPlugin())
        app.addPlugin(TileMapPlugin())
        app.addPlugin(Core2DPlugin())
        app.addPlugin(Light2DPlugin())
        app.addPlugin(UpscalePlugin())

        app.insertResource(PrimaryWindowId(windowId: RID()))

        return app
    }
}
