//
//  UIPlugin.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import AdaApp
import AdaECS
@_spi(Internal) import AdaInput
import AdaRender
import AdaCorePipelines
import AdaText
import AdaUtils
import Math
import Logging

public struct UIPlugin: Plugin {
    public init() { }

    public func setup(in app: AppWorlds) {
        UIComponent.registerComponent()

        app
            .addSystem(UpdateWindowManagerSystem.self, on: .preUpdate)
            .addSystem(UIComponentSystem.self)
            .insertResource(UIWindowPendingDrawViews())
            .insertResource(UIContextPendingDraw())
            .insertResource(UIRedrawRequest())

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        // Register resources for UI rendering
        renderWorld
            .insertResource(ExtractedUIComponents())
            .insertResource(ExtractedUIContexts())
            .insertResource(PendingUIGraphicsContext())
            .insertResource(RenderItems<UITransparentRenderItem>())
            .insertResource(UIDrawPass())
            .insertResource(UIViewUniform())
            .insertResource(UIRenderBuildState())
            .insertResource(UILayerDrawCache())
            .insertResource(GlassBackgroundTexture())
            .insertResource(RenderPipelines(configurator: LinearGradientPipeline()))
            .insertResource(RenderPipelines(configurator: GlassPipeline()))

        renderWorld.initResource(UIRenderPipelines.self)

        let renderGraph = renderWorld.getRefResource(RenderGraph.self)
        do {
            try renderGraph.wrappedValue.updateSubgraph(by: .main2D) { graph in
                graph.addNode(UIRenderNode())

                // After Main2D, UIRenderNode blits scene color → GlassBackgroundTexture on the
                // same command buffer as the UI pass (blur/refraction must see a completed snapshot).
                graph.removeNodeEdge(from: Main2DRenderNode.name, to: RenderNodeLabel.Main2D.endPass)
                graph.addNodeEdge(from: Main2DRenderNode.self, to: UIRenderNode.self)
                graph.addNodeEdge(from: UIRenderNode.name, to: RenderNodeLabel.Main2D.endPass)
            }

            // Add UI rendering systems
            renderWorld.addSystem(ExtractUIComponentsSystem.self, on: .extract)
            renderWorld.addSystem(UIRenderPreparingSystem.self, on: .prepare)
            renderWorld.addSystem(UIRenderTesselationSystem.self, on: .update)
        } catch {
            Logger(label: "org.adaengine.UIRenderPlugin").error("\(error)")
        }
    }
}

public struct WindowPlugin: Plugin {
    let primaryWindow: UIWindow?

    public init(primaryWindow: UIWindow? = nil) {
        self.primaryWindow = primaryWindow
    }

    public func setup(in app: AppWorlds) {
        guard let windowSettings = app.getResource(WindowSettings.self) else {
            return
        }

        if let primaryWindow {
            primaryWindow.showWindow(makeFocused: true)
            app
                .insertResource(PrimaryWindow(window: primaryWindow))
                .insertResource(PrimaryWindowId(windowId: primaryWindow.id))
        } else {
            let window = UIWindow()
            window.title = windowSettings.title ?? "App"
            #if os(iOS) || os(tvOS) || os(watchOS)
            let embeddedWindowSize = Screen.main?.size ?? windowSettings.minimumSize
            window.minSize = embeddedWindowSize
            window.frame = Rect(origin: .zero, size: embeddedWindowSize)
            window.setWindowMode(.fullscreen)
            #else
            window.minSize = windowSettings.minimumSize
            window.frame = Rect(origin: .zero, size: windowSettings.minimumSize)
            window.setWindowMode(
                windowSettings.windowMode == .fullscreen ? .fullscreen : .windowed
            )
            #endif
            window.showWindow(makeFocused: true)
            app
                .insertResource(PrimaryWindow(window: window))
                .insertResource(PrimaryWindowId(windowId: window.id))
        }
    }
}

public struct PrimaryWindow: Resource {
    public let window: UIWindow
}

public struct WindowManagerResource: Resource {
    public let windowManager: UIWindowManager

    public init(windowManager: UIWindowManager) {
        self.windowManager = windowManager
    }
}

@System(dependencies: [
    .after(InputEventParseSystem.self)
])
@inline(__always)
@MainActor
public func UpdateWindowManager(
    _ context: WorldUpdateContext,
    _ windowManager: Res<WindowManagerResource>,
    _ pendingViews: ResMut<UIWindowPendingDrawViews>,
    _ contexts: ResMut<UIContextPendingDraw>,
    _ redrawRequest: ResMut<UIRedrawRequest>,
    _ input: ResMut<Input>,
    _ deltaTime: Res<DeltaTime>
) {
    pendingViews.windows.removeAll(keepingCapacity: true)
    contexts.contexts.removeAll(keepingCapacity: true)
    redrawRequest.needsRedraw = false
    let windowManager = windowManager.windowManager
    let deltaTime = deltaTime.deltaTime
    let windows = windowManager.windows
    for window in windows {
        let menuBuilder = windowManager.menuBuilder(for: window)
        menuBuilder?.updateIfNeeded()

        for event in input.wrappedValue.eventsPool where event.window == window.id {
            window.sendEvent(event)
        }

        window.internalUpdate(deltaTime)
        if window.canDraw && window.needsDisplay {
            pendingViews.windows.append(window)
            redrawRequest.needsRedraw = true
            window.needsDisplay = false
        }
    }
}

public struct UIWindowPendingDrawViews: Resource {
    public var windows: [UIWindow] = []
}

public struct UIContextPendingDraw: Resource {
    public var contexts: [UIGraphicsContext] = []
}

public struct UIRedrawRequest: Resource {
    public var needsRedraw: Bool = true
}
