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
                .update,
                .render,
                .postUpdate
            ]))
        renderWorld.setExctractor(RenderWorldExctractor())
        renderWorld.main.setSchedulers([
            .extract,
            .preUpdate,
            .prepare,
            .update,
            .render,
            .postUpdate
        ])

        unsafe renderWorld
            .insertResource(RenderDeviceHandler(renderDevice: RenderEngine.shared.renderDevice))
            .insertResource(WindowSurfaces(windows: [:]))
            .addSystem(CreateWindowSurfacesSystem.self, on: .prepare)
            .addSystem(DefaultSchedulerRunner.self, on: .renderRunner)
            .addSystem(RenderSystem.self, on: .render)

        app.addSubworld(renderWorld, by: .renderWorld)
    }
}

public struct RenderDeviceHandler: Resource {
    public var renderDevice: RenderDevice

    public init(renderDevice: RenderDevice) {
        self.renderDevice = renderDevice
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
    Task.detached(priority: .high) { [renderGraph] in
        do {
            guard
                let renderGraph,
                let renderDevice = renderDevice.wrappedValue?.renderDevice
            else {
                return
            }
            let renderGraphExecutor = RenderGraphExecutor()
            try await renderGraphExecutor.execute(renderGraph, renderDevice: renderDevice, in: world)

            for window in surfaces.windows {
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
    _ renderDevice: Res<RenderDeviceHandler>
) async {
    surfaces.windows.removeAll()
    let device = renderDevice.renderDevice

    do {
        let renderWindows = unsafe try await RenderEngine.shared.getRenderWindows()
        for (ref, _) in renderWindows.windows.values {
            let swapchain = await renderDevice.renderDevice.createSwapchain(from: ref)
            surfaces.windows[ref] = WindowSurface(
                swapchain: swapchain,
                currentDrawable: swapchain.getNextDrawable(device)
            )
        }
    } catch {
        print("CreateWindowSurfaces", error.localizedDescription)
    }
}

public struct RenderWindows: Resource {
    public var windows: SparseSet<WindowRef, RenderWindow>

    public init(windows: SparseSet<WindowRef, RenderWindow>) {
        self.windows = windows
    }
}

public struct RenderWindow: Sendable, Hashable {
    public var windowRef: WindowRef
    public var height: Int
    public var width: Int

    public init(windowRef: WindowRef, height: Int, width: Int) {
        self.windowRef = windowRef
        self.height = height
        self.width = width
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
