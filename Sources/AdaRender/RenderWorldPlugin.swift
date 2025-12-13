//
//  WorldPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

import AdaApp
import AdaECS
import AdaUtils
import Foundation
import Math

/// The plugin that sets up the render world.
public struct RenderWorldPlugin: Plugin {
    public init() {}

    /// Setup the render world.
    /// - Parameter app: The app to setup the render world for.
    public func setup(in app: AppWorlds) {
        VisibleEntities.registerComponent()
        Visibility.registerComponent()
        NoFrustumCulling.registerComponent()
        BoundingComponent.registerComponent()
        Texture.registerTypes()

        let renderWorld = AppWorlds(main: World(name: "RenderWorld"))
        renderWorld.updateScheduler = .renderRunner
        renderWorld
            .insertResource(RenderGraph(label: "RenderWorld_Root"))
            .insertResource(DefaultSchedulerOrder(order: [
                .preUpdate,
                .prepare,
                .update,
                .render,
                .postUpdate
            ]))
        renderWorld.setExctractor(RenderWorldExctractor())
        renderWorld.main.setSchedulers([
            .startup,
            .extract,
            .preUpdate,
            .prepare,
            .update,
            .render,
            .postUpdate
        ])

        renderWorld
            .insertResource(RenderDeviceHandler(renderDevice: RenderEngine.shared.renderDevice))
            .insertResource(WindowSurfaces(windows: [:]))
            .addSystem(CreateWindowSurfacesSystem.self, on: .prepare)
            .addSystem(DefaultSchedulerRunner.self, on: .renderRunner)
            .addSystem(RenderSystem.self, on: .render)

        app.addSubworld(renderWorld, by: .renderWorld)
        app.addPlugin(UpscalePlugin())
    }
}

public struct RenderDeviceHandler: Resource {
    public var renderDevice: RenderDevice

    public init(renderDevice: RenderDevice) {
        self.renderDevice = renderDevice
    }
}

public struct RenderEngineHandler: Resource {
    public var renderEngine: RenderEngine

    public init(renderEngine: RenderEngine) {
        self.renderEngine = renderEngine
    }
}

@System
func Render(
    _ context: WorldUpdateContext,
    _ renderGraph: Res<RenderGraph?>,
    _ surfaces: Res<WindowSurfaces>,
    _ renderDevice: Res<RenderDeviceHandler?>
) {
    let world = context.world
    let renderGraph = renderGraph.wrappedValue
    renderGraph?.update(from: world)
    
    // We should capture drawables before we start async task.
    // Because we can have a situation when we start task, but main thread already cleared surfaces.
    let windows = surfaces.windows
    
    Task { @RenderGraphActor [renderGraph] in
        do {
            guard
                let renderGraph,
                let renderDevice = renderDevice.wrappedValue?.renderDevice
            else {
                return
            }
            let renderGraphExecutor = RenderGraphExecutor()
            try await renderGraphExecutor.execute(renderGraph, renderDevice: renderDevice, in: world)

            for window in windows {
                try window.currentDrawable?.present()
            }
        } catch {
            assertionFailure("Failed to execute render graph \(error)")
        }
    }
}

/// The extractor that extracts the main world to the render world.
struct RenderWorldExctractor: WorldExctractor {
    func exctract(from mainWorld: World, to renderWorld: World) async {
        renderWorld.clear()
        renderWorld.insertResource(MainWorld(world: mainWorld))
        await renderWorld.runScheduler(.extract)
    }
}

/// The resource that contains the main world.
struct MainWorld: Resource {
    var world: World
}

public struct WindowSurface: Sendable {
    public var swapchain: (any Swapchain)?
    public var currentDrawable: (any Drawable)?
}

public struct WindowSurfaces: Resource {
    public var windows: SparseSet<WindowRef, WindowSurface>
}

@System
func CreateWindowSurfaces(
    _ surfaces: ResMut<WindowSurfaces>,
    _ renderDevice: Res<RenderDeviceHandler>,
    _ primaryWindow: Extract<Res<PrimaryWindowId>>
) async {
    surfaces.windows.removeAll()
    let device = renderDevice.renderDevice

    do {
        let renderWindows = try await RenderEngine.shared.getRenderWindows()
        for (windowId, _) in renderWindows.windows.values {
            let swapchain = await device.createSwapchain(from: windowId)

            let ref: WindowRef = if primaryWindow.wrappedValue.windowId == windowId {
                    .primary
                } else {
                    .windowId(windowId)
                }
            surfaces.windows[ref] = WindowSurface(
                swapchain: swapchain,
                currentDrawable: swapchain.getNextDrawable(device)
            )
        }
    } catch {
        print("CreateWindowSurfaces", error.localizedDescription)
    }
}

public struct PrimaryWindowId: Resource {
    public var windowId: RID

    public init(windowId: RID) {
        self.windowId = windowId
    }
}

public struct RenderWindows: Resource {
    public var windows: SparseSet<WindowID, RenderWindow>

    public init(windows: SparseSet<WindowID, RenderWindow>) {
        self.windows = windows
    }
}

public struct RenderWindow: Sendable, Hashable {
    public var windowId: WindowID
    public var height: Int
    public var width: Int
    public var scaleFactor: Float

    public var physicalSize: Size {
        Size(
            width: Float(width) * scaleFactor,
            height: Float(height) * scaleFactor
        )
    }

    public var logicalSize: SizeInt {
        SizeInt(width: width, height: height)
    }

    public init(windowId: WindowID, height: Int, width: Int, scaleFactor: Float) {
        self.windowId = windowId
        self.height = height
        self.width = width
        self.scaleFactor = scaleFactor
    }
}

public extension SchedulerName {
    /// The render scheduler.
    static let renderRunner = SchedulerName(rawValue: "RenderWorld_RenderRunner")

    static let prepare = SchedulerName(rawValue: "RenderWorld_Prepare")
    static let render = SchedulerName(rawValue: "RenderWorld_Render")
    static let extract = SchedulerName(rawValue: "RenderWorld_Extract")
}

public extension AppWorldName {
    /// The render world that will render the scene.
    static let renderWorld = AppWorldName(rawValue: "RenderWorld")
}
