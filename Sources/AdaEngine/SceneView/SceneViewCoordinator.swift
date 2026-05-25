//
//  SceneViewCoordinator.swift
//  AdaEngine
//
//  Created by AdaEngine on 04.04.2026.
//

import AdaApp
import AdaAssets
import AdaAudio
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
    private var targetRenderTexture: RenderTexture?
    private var renderTexturePool: [RenderTexture] = []
    private var pendingDisplayTargets: [PendingDisplayTarget] = []
    private var retiredDisplayTargets: [RetiredDisplayTarget] = []
    private var nextRenderTextureIndex = 0
    private(set) var renderTexture: Texture2D?

    private var isBootstrapping = false
    private var isShutdown = false
    private var hasCalledSetup = false
    /// When true, this coordinator's ``AppWorlds`` is a subworld of ``AppWorldsSession/current`` and is updated by the host ``AppWorlds/update()`` loop (no separate ``tick`` work).
    private var isHostedSubworld = false
    /// Fallback when no host session exists (e.g. unusual test harnesses).
    private var standaloneTickInFlight = false

    private let hostSubworldName: AppWorldName
    private var currentSize: SizeInt = .zero
    private var scaleFactor: Float = 1

    private let filePath: StaticString
    private let pluginPreset: SceneViewPluginPreset
    private let setupClosure: @MainActor (World) -> Void
    private let updateClosure: @MainActor (World, AdaUtils.TimeInterval) -> Void
    private let inputClosure: @MainActor (any InputEvent, World) -> Bool

    private struct PendingDisplayTarget {
        var texture: RenderTexture
        var isCompleted = false
    }

    private struct RetiredDisplayTarget {
        var texture: RenderTexture
        var remainingFrames: Int
    }

    init(
        filePath: StaticString,
        pluginPreset: SceneViewPluginPreset,
        setup: @escaping @MainActor (World) -> Void,
        update: @escaping @MainActor (World, AdaUtils.TimeInterval) -> Void,
        input: @escaping @MainActor (any InputEvent, World) -> Bool
    ) {
        self.filePath = filePath
        self.pluginPreset = pluginPreset
        self.setupClosure = setup
        self.updateClosure = update
        self.inputClosure = input
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
        guard appWorlds == nil && !isBootstrapping && !isShutdown else { return }
        isBootstrapping = true

        Task { @MainActor [weak self] in
            guard let self, !self.isShutdown else { return }
            let app = self.buildAppWorlds()
            guard !self.isShutdown else {
                self.isBootstrapping = false
                return
            }
            if let host = AppWorldsSession.current {
                host.addSubworld(app, by: self.hostSubworldName)
                self.isHostedSubworld = true
            } else {
                self.isHostedSubworld = false
            }
            try? await app.build()
            guard !self.isShutdown else {
                AppWorldsSession.current?.removeSubworld(by: self.hostSubworldName)
                self.isBootstrapping = false
                return
            }
            self.appWorlds = app
            self.isBootstrapping = false
            self.finalizeSetupIfReady()
        }
    }

    func shutdown() {
        isShutdown = true
        stopAudioPlaybacks()
        AppWorldsSession.current?.removeSubworld(by: hostSubworldName)
        appWorlds = nil
        cameraEntity = nil
        targetRenderTexture = nil
        renderTexturePool.removeAll()
        pendingDisplayTargets.removeAll()
        retiredDisplayTargets.removeAll()
        nextRenderTextureIndex = 0
        renderTexture = nil
        isBootstrapping = false
        hasCalledSetup = false
        isHostedSubworld = false
        standaloneTickInFlight = false
    }

    func updateSize(_ size: SizeInt, scaleFactor: Float) {
        guard size.width > 0 && size.height > 0 else { return }
        guard size != currentSize || scaleFactor != self.scaleFactor else { return }
        currentSize = size
        self.scaleFactor = scaleFactor

        rebuildRenderTexturePool(size: size, scaleFactor: scaleFactor)

        if let entity = cameraEntity, let app = appWorlds {
            if let targetRenderTexture {
                updateCameraTarget(app: app, entity: entity, texture: targetRenderTexture)
            }
        } else {
            finalizeSetupIfReady()
        }
    }

    func tick(_ deltaTime: AdaUtils.TimeInterval) {
        guard let appWorlds, hasCalledSetup else {
            return
        }
        updateClosure(appWorlds.main, deltaTime)
        ageRetiredDisplayTargets()
        prepareNextRenderTarget()

        if isHostedSubworld {
            return
        }
        standaloneTick(deltaTime)
    }

    func receiveInputEvent(_ event: any InputEvent) {
        guard let app = appWorlds else { return }
        if inputClosure(event, app.main) {
            return
        }

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

    private func stopAudioPlaybacks() {
        guard let appWorlds else {
            return
        }

        for entity in appWorlds.main.getEntities() {
            entity.components[AudioComponent.self]?.playbackController.stop()
            entity.stopAllAudio()
        }
    }

    private func finalizeSetupIfReady() {
        guard let app = appWorlds,
              currentSize.width > 0 && currentSize.height > 0,
              !hasCalledSetup else { return }

        if targetRenderTexture == nil {
            rebuildRenderTexturePool(size: currentSize, scaleFactor: scaleFactor)
        }

        spawnCamera(in: app)
        setupClosure(app.main)
        hasCalledSetup = true
    }

    private func spawnCamera(in app: AppWorlds) {
        guard let texture = targetRenderTexture else {
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

    private func rebuildRenderTexturePool(size: SizeInt, scaleFactor: Float) {
        let poolSize = max(3, unsafe RenderEngine.configurations.maxFramesInFlight + 2)
        renderTexturePool = (0..<poolSize).map { index in
            let texture = RenderTexture(
                size: size,
                scaleFactor: scaleFactor,
                format: .bgra8,
                debugLabel: "SceneView_RenderTarget_\(index)"
            )
            texture.renderCompletedHandler = { [weak self] texture in
                Task { @MainActor in
                    self?.completeRenderTexture(texture)
                }
            }
            return texture
        }
        pendingDisplayTargets.removeAll()
        retiredDisplayTargets.removeAll()
        nextRenderTextureIndex = 0
        renderTexture = nil

        if let texture = nextAvailableRenderTexture() {
            setTargetRenderTexture(texture)
        }
    }

    private func setTargetRenderTexture(_ texture: RenderTexture) {
        targetRenderTexture = texture
    }

    @discardableResult
    private func publishRenderTextureIfReady() -> Bool {
        guard !pendingDisplayTargets.isEmpty else {
            return false
        }

        var didPublish = false
        while let firstTarget = pendingDisplayTargets.first,
              firstTarget.isCompleted {
            let completedTarget = pendingDisplayTargets.removeFirst()
            if let currentFront = renderTexture as? RenderTexture,
               currentFront !== completedTarget.texture {
                retiredDisplayTargets.append(
                    RetiredDisplayTarget(
                        texture: currentFront,
                        remainingFrames: max(1, unsafe RenderEngine.configurations.maxFramesInFlight)
                    )
                )
            }
            renderTexture = completedTarget.texture
            didPublish = true
        }
        return didPublish
    }

    private func completeRenderTexture(_ texture: RenderTexture) {
        guard let index = pendingDisplayTargets.firstIndex(where: { $0.texture === texture }) else {
            return
        }

        pendingDisplayTargets[index].isCompleted = true
        publishRenderTextureIfReady()
    }

    private func prepareNextRenderTarget() {
        if let targetRenderTexture,
           !isDisplayUnavailable(targetRenderTexture),
           !pendingDisplayTargets.contains(where: { $0.texture === targetRenderTexture }) {
            scheduleForDisplay(targetRenderTexture)
            return
        }

        guard let texture = nextAvailableRenderTexture() else {
            return
        }

        setTargetRenderTexture(texture)
        if let entity = cameraEntity, let app = appWorlds {
            updateCameraTarget(app: app, entity: entity, texture: texture)
        }
        scheduleForDisplay(texture)
    }

    private func scheduleForDisplay(_ texture: RenderTexture) {
        guard !pendingDisplayTargets.contains(where: { $0.texture === texture }) else {
            return
        }

        pendingDisplayTargets.append(PendingDisplayTarget(texture: texture))
    }

    private func nextAvailableRenderTexture() -> RenderTexture? {
        guard !renderTexturePool.isEmpty else {
            return nil
        }

        let unavailable = Set((pendingDisplayTargets.map { ObjectIdentifier($0.texture) })
            + retiredDisplayTargets.map { ObjectIdentifier($0.texture) }
            + [renderTexture].compactMap { texture -> ObjectIdentifier? in
                guard let texture = texture as? RenderTexture else {
                    return nil
                }
                return ObjectIdentifier(texture)
            })

        for offset in 0..<renderTexturePool.count {
            let index = (nextRenderTextureIndex + offset) % renderTexturePool.count
            let texture = renderTexturePool[index]
            guard !unavailable.contains(ObjectIdentifier(texture)) else {
                continue
            }

            nextRenderTextureIndex = (index + 1) % renderTexturePool.count
            return texture
        }

        return nil
    }

    private func isDisplayUnavailable(_ texture: RenderTexture) -> Bool {
        if let frontTexture = renderTexture as? RenderTexture, frontTexture === texture {
            return true
        }
        if pendingDisplayTargets.contains(where: { $0.texture === texture }) {
            return true
        }
        if retiredDisplayTargets.contains(where: { $0.texture === texture }) {
            return true
        }
        return false
    }

    private func ageRetiredDisplayTargets() {
        for index in retiredDisplayTargets.indices {
            retiredDisplayTargets[index].remainingFrames -= 1
        }
        retiredDisplayTargets.removeAll { $0.remainingFrames <= 0 }
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

        switch pluginPreset {
        case .standard:
            app.addPlugin(SpritePlugin())
            app.addPlugin(Mesh2DPlugin())
            app.addPlugin(TextPlugin())
            app.addPlugin(ScenePlugin())
            app.addPlugin(ScriptableObjectPlugin())
            app.addPlugin(Physics2DPlugin())
            app.addPlugin(TileMapPlugin())
            app.addPlugin(Core2DPlugin())
            app.addPlugin(Core3DPlugin())
            app.addPlugin(Light2DPlugin())
            app.addPlugin(UpscalePlugin())
        case .mesh2D:
            app.addPlugin(SpritePlugin())
            app.addPlugin(Mesh2DPlugin())
            app.addPlugin(Core2DPlugin())
        }

        app.insertResource(PrimaryWindowId(windowId: RID()))

        return app
    }
}
