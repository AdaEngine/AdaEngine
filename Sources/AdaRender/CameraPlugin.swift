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

    public init() {}
}

@System
func ConfigurateRenderViewTarget(
    _ query: Query<Entity, Camera, Ref<RenderViewTarget>>,
    _ surfaces: Res<WindowSurfaces>,
    _ renderDevice: Res<RenderDeviceHandler>
) {
    let logger = Logger(label: "ConfigurateRenderViewTarget")
    query.forEach { entity, camera, renderViewTarget in
        let viewportSize = camera.viewport?.rect.size.toSizeInt() ?? SizeInt(width: 800, height: 600)
        
        if renderViewTarget.mainTexture == nil {
            renderViewTarget.mainTexture = RenderTexture(
                size: viewportSize,
                scaleFactor: camera.computedData.targetScaleFactor,
                format: .bgra8,
                debugLabel: "Camera Main Texture"
            )
        }

        switch camera.renderTarget {
        case .texture(let asset):
            renderViewTarget.outputTexture = asset.asset
        case .window(let ref):
            guard
                let surface = surfaces.windows[ref],
                let swapchain = surface.swapchain,
                let drawable = surface.currentDrawable
            else {
                logger.error("Failed to configurate render view target for window \(ref)")
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
    @Query<Entity, Camera>
    private var query

    func update(from world: World) {
        query.update(from: world)
    }

    func execute(context: inout Context, renderContext: RenderContext) async -> [RenderSlotValue] {
        query.forEach { (entity, camera) in
            guard camera.isActive else {
                return
            }

            context.runSubgraph(.main2D, inputs: [
                RenderSlotValue(name: Scene2DPlugin.InputNode.view, value: .entity(entity))
            ], viewEntity: entity)
        }

        return []
    }
}
