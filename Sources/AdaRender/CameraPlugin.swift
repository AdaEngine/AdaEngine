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
import Math

public struct CameraPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        Camera.registerComponent()
        app.addSystem(CameraSystem.self)

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        renderWorld
            .addSystem(ExtractCameraSystem.self, on: .extract)
            .addSystem(ConfigurateRenderViewTargetSystem.self, on: .update)
            .getRefResource(RenderGraph.self)
            .wrappedValue
            .addNode(CameraRenderNode())
    }
}

@Component
public struct RenderViewTarget: @unchecked Sendable {
    public var mainTexture: RenderTexture?
    public var outputTexture: RenderTexture?
    
    var swapchain: (any Swapchain)?
    var currentDrawable: (any Drawable)?

    public init() {}
}

@System
func ConfigurateRenderViewTarget(
    _ query: Query<Entity, Camera, Ref<RenderViewTarget>>,
    _ renderDevice: Res<RenderDeviceHandler>
) async {
    var items: [(Entity, Camera, Ref<RenderViewTarget>)] = []
    query.forEach { entity, camera, target in
        items.append((entity, camera, target))
    }

    for (_, camera, renderViewTarget) in items {
        let viewportSize = camera.viewport?.rect.size.toSizeInt() ?? SizeInt(width: 800, height: 600)
        
        if renderViewTarget.mainTexture == nil {
            renderViewTarget.mainTexture = RenderTexture(
                size: viewportSize,
                scaleFactor: 1.0,
                format: .bgra8,
                debugLabel: "Camera Main Texture"
            )
        }

        switch camera.renderTarget {
        case .texture(let asset):
            renderViewTarget.outputTexture = asset.asset
        case .window(let ref):
            let swapchain: any Swapchain
            
            if let existingSwapchain = renderViewTarget.swapchain {
                swapchain = existingSwapchain
            } else {
                swapchain = await MainActor.run {
                    renderDevice.renderDevice.createSwapchain(from: ref)
                }
                renderViewTarget.swapchain = swapchain
            }
            
            if let drawable = swapchain.getNextDrawable() {
                renderViewTarget.currentDrawable = drawable
                renderViewTarget.outputTexture = RenderTexture(
                    gpuTexture: drawable.texture,
                    size: viewportSize,
                    format: swapchain.drawablePixelFormat
                )
            }
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

             context.runSubgraph(by: Scene2DPlugin.renderGraph, inputs: [
                RenderSlotValue(name: Scene2DPlugin.InputNode.view, value: .entity(entity))
            ], viewEntity: entity)
        }

        return []
    }
}
