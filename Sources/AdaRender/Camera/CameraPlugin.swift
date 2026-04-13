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

    /// Scene albedo when the 2D lighting pipeline is active; otherwise unused.
    public var sceneColorTexture: RenderTexture?
    /// Additive light accumulation (same size as ``mainTexture``).
    public var lightAccumTexture: RenderTexture?
    /// Shadow mask written before each lit pass (same size as ``mainTexture``).
    public var shadowMaskTexture: RenderTexture?

    /// When true, ``Main2DRenderNode`` writes albedo to ``sceneColorTexture``; lighting composite writes ``mainTexture``.
    public var lighting2DUsesDeferredTargets: Bool = false

    public init() {}
}

@System(
    dependencies: [.after("AdaRender.CreateWindowSurfacesSystem")]
)
func ConfigurateRenderViewTarget(
    _ query: Query<Entity, Camera, Ref<RenderViewTarget>>,
    _ surfaces: Res<WindowSurfaces>,
    _ renderDevice: Res<RenderDeviceHandler>
) {
    let logger = Logger(label: "org.adaengine.AdaRender.ConfigurateRenderViewTarget")
    query.forEach { entity, camera, renderViewTarget in
        let viewportSize = camera.viewport.rect.size.toSizeInt()

        guard viewportSize.width != 0 && viewportSize.height != 0 else {
            return
        }

        let scale = camera.computedData.targetScaleFactor
        if renderViewTarget.mainTexture == nil || renderViewTarget.mainTexture?.size != viewportSize {
            renderViewTarget.mainTexture = RenderTexture(
                size: viewportSize,
                scaleFactor: scale,
                format: .bgra8,
                debugLabel: "Camera Main Texture"
            )
            renderViewTarget.sceneColorTexture = nil
            renderViewTarget.lightAccumTexture = nil
            renderViewTarget.shadowMaskTexture = nil
        }

        switch camera.renderTarget {
        case .texture(let asset):
            renderViewTarget.outputTexture = asset.asset
        case .window(let ref):
            guard let surface = surfaces.windows[ref] else {
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
    }
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
    query.wrappedValue.forEach {
        entity, camera, transform,
        visibleEntities, uniform, graph in
        commands.spawn("ExtractedCameraEntity") {
            camera
            transform
            visibleEntities
            uniform
            RenderViewTarget()
            graph
        }
    }
}
