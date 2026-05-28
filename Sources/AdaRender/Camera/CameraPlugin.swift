//
//  CameraPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

import AdaApp
import AdaAssets
import AdaECS
import AdaTransform
import AdaUtils
import Logging
import Math

public struct CameraPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        Camera.registerComponent()
        app.addSystem(CameraSystem.self, on: .preUpdate)

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        renderWorld
            .insertResource(ExtractedCameraRenderViewTargets())
            .addSystem(ExtractCameraSystem.self, on: .extract)
            .addSystem(ConfigurateRenderViewTargetSystem.self, on: .prepare)
            .getRefResource(RenderGraph.self)
            .wrappedValue
            .addNode(CameraRenderNode())
    }
}

@Component
public struct RenderViewTarget: @unchecked Sendable {
    public var mainTexture: RenderTexture?
    public var outputTexture: RenderTexture?
    public var depthTexture: RenderTexture?
    var retiredFrameTextures: [RetiredFrameTexture] = []

    /// Scene albedo when the 2D lighting pipeline is active; otherwise unused.
    public var sceneColorTexture: RenderTexture?
    /// Additive light accumulation (same size as ``mainTexture``).
    public var lightAccumTexture: RenderTexture?
    /// Shadow mask written before each lit pass (same size as ``mainTexture``).
    public var shadowMaskTexture: RenderTexture?

    /// When true, ``Main2DRenderNode`` writes albedo to ``sceneColorTexture``; lighting composite writes ``mainTexture``.
    public var lighting2DUsesDeferredTargets: Bool = false

    public init() {}

    fileprivate var cacheableCopy: RenderViewTarget {
        var copy = self
        copy.outputTexture = nil
        return copy
    }
}

struct RetiredFrameTexture: Sendable {
    var texture: RenderTexture
    var remainingFrames: Int
}

public struct ExtractedCameraRenderViewTargets: Resource {
    var targets: [Entity.ID: RenderViewTarget] = [:]
}

@Component
public struct ExtractedCameraSource: Sendable {
    let entityId: Entity.ID
}

@System(
    dependencies: [.after("AdaRender.CreateWindowSurfacesSystem")]
)
func ConfigurateRenderViewTarget(
    _ query: Query<Entity, Camera, Ref<RenderViewTarget>, ExtractedCameraSource>,
    _ surfaces: Res<WindowSurfaces>,
    _ primaryWindow: Res<PrimaryWindowId?>,
    _ renderDevice: Res<RenderDeviceHandler>,
    _ cachedViewTargets: ResMut<ExtractedCameraRenderViewTargets>
) {
    let logger = Logger(label: "org.adaengine.AdaRender.ConfigurateRenderViewTarget")
    query.forEach { entity, camera, renderViewTarget, source in
        let viewportSize = camera.viewport.rect.size.toSizeInt()

        guard viewportSize.width != 0 && viewportSize.height != 0 else {
            return
        }

        let scale = camera.computedData.targetScaleFactor
        ageRetiredFrameTextures(renderViewTarget)

        if case .texture(let asset) = camera.renderTarget {
            let outputTexture = asset.asset
            renderViewTarget.outputTexture = outputTexture
            renderViewTarget.mainTexture = outputTexture
            renderViewTarget.depthTexture = nil
            renderViewTarget.retiredFrameTextures.removeAll(keepingCapacity: false)
            renderViewTarget.sceneColorTexture = nil
            renderViewTarget.lightAccumTexture = nil
            renderViewTarget.shadowMaskTexture = nil
            cachedViewTargets.targets[source.entityId] = nil
            return
        }

        if renderViewTarget.mainTexture == nil
            || renderViewTarget.mainTexture?.size != viewportSize
            || renderViewTarget.mainTexture?.scaleFactor != scale {
            let retiredTextures = [
                renderViewTarget.mainTexture,
                renderViewTarget.depthTexture,
                renderViewTarget.sceneColorTexture,
                renderViewTarget.lightAccumTexture,
                renderViewTarget.shadowMaskTexture,
            ].compactMap { $0 }
            renderViewTarget.retiredFrameTextures.append(contentsOf: retireFrameTextures(retiredTextures))
            let maxRetainedTextures = unsafe RenderEngine.configurations.maxFramesInFlight * max(1, retiredTextures.count)
            if renderViewTarget.retiredFrameTextures.count > maxRetainedTextures {
                renderViewTarget.retiredFrameTextures.removeFirst(
                    renderViewTarget.retiredFrameTextures.count - maxRetainedTextures
                )
            }
            renderViewTarget.mainTexture = RenderTexture(
                size: viewportSize,
                scaleFactor: scale,
                format: .bgra8,
                debugLabel: "Camera Main Texture"
            )
            
            renderViewTarget.depthTexture = RenderTexture(
                size: viewportSize,
                scaleFactor: scale,
                format: .depth_32f_stencil8,
                debugLabel: "Camera Depth Texture"
            )
            
            renderViewTarget.sceneColorTexture = nil
            renderViewTarget.lightAccumTexture = nil
            renderViewTarget.shadowMaskTexture = nil
        }

        switch camera.renderTarget {
        case .texture:
            break
        case .window(let ref):
            renderViewTarget.outputTexture = nil
            guard let surface = resolveWindowSurface(for: ref, in: surfaces.wrappedValue, primaryWindow: primaryWindow.wrappedValue) else {
                logger.error("Failed to configurate render view target for window \(ref). No surface.")
                return
            }
            guard let swapchain = surface.swapchain else {
                logger.error("Failed to configurate render view target for window \(ref). No swapchain.")
                return
            }
            guard let drawable = surface.currentDrawable else {
                logger.error("Failed to configurate render view target for window \(ref). Drawable not exists.")
                return
            }
            renderViewTarget.outputTexture = RenderTexture(
                gpuTexture: drawable.texture,
                format: swapchain.drawablePixelFormat
            )
        }

        cachedViewTargets.targets[source.entityId] = renderViewTarget.wrappedValue.cacheableCopy
    }
}

private func retireFrameTextures(_ textures: [RenderTexture]) -> [RetiredFrameTexture] {
    let remainingFrames = max(1, unsafe RenderEngine.configurations.maxFramesInFlight)
    return textures.map {
        RetiredFrameTexture(texture: $0, remainingFrames: remainingFrames)
    }
}

private func ageRetiredFrameTextures(_ renderViewTarget: Ref<RenderViewTarget>) {
    guard !renderViewTarget.retiredFrameTextures.isEmpty else {
        return
    }

    for index in renderViewTarget.retiredFrameTextures.indices {
        renderViewTarget.retiredFrameTextures[index].remainingFrames -= 1
    }
    renderViewTarget.retiredFrameTextures.removeAll { $0.remainingFrames <= 0 }
}

func resolveWindowSurface(
    for ref: WindowRef,
    in surfaces: WindowSurfaces,
    primaryWindow: PrimaryWindowId?
) -> WindowSurface? {
    if let surface = surfaces.windows[ref] {
        return surface
    }

    guard case .windowId(let windowId) = ref,
          primaryWindow?.windowId == windowId
    else {
        return nil
    }

    return surfaces.windows[.primary]
}

struct CameraRenderNode: RenderNode {
    @Query<Entity, Camera, CameraRenderGraph>
    private var query

    func update(from world: World) {
        query.update(from: world)
    }

    func execute(context: inout Context, renderContext: RenderContext) async -> [RenderSlotValue] {
        query.forEach { (entity, camera, renderSubGraph) in
            guard camera.isActive else {
                return
            }

            context.runSubgraph(renderSubGraph.subgraphLabel, inputs: [
                RenderSlotValue(name: renderSubGraph.inputSlot, value: .entity(entity))
            ], viewEntity: entity)
        }
        return []
    }
}

@Component
public struct CameraRenderGraph {
    public let subgraphLabel: RenderGraph.Label
    public let inputSlot: RenderSlot.Label

    public init(subgraphLabel: RenderGraph.Label, inputSlot: RenderSlot.Label) {
        self.subgraphLabel = subgraphLabel
        self.inputSlot = inputSlot
    }
}

@System
@inline(__always)
public func ExtractCamera(
    _ world: World,
    _ commands: Commands,
    _ cachedViewTargets: ResMut<ExtractedCameraRenderViewTargets>,
    _ query: Extract<
        Query<
        Entity,
        Camera,
        Transform,
        VisibleEntities,
        GlobalViewUniform,
        CameraRenderGraph
        >
    >
) {
    var activeCameraIds = Set<Entity.ID>()

    query.wrappedValue.forEach {
        entity, camera, transform,
        visibleEntities, uniform, graph in
        activeCameraIds.insert(entity.id)

        let renderViewTarget = cachedViewTargets.targets[entity.id]?.cacheableCopy ?? RenderViewTarget()
        commands.spawn("ExtractedCameraEntity") {
            camera
            transform
            visibleEntities
            uniform
            renderViewTarget
            ExtractedCameraSource(entityId: entity.id)
            graph
        }
    }

    cachedViewTargets.targets = cachedViewTargets.targets.filter { activeCameraIds.contains($0.key) }
}
