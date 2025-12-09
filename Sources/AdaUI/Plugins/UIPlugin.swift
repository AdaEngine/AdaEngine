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
import AdaUtils
import Math

public struct UIPlugin: Plugin {
    public init() { }

    public func setup(in app: AppWorlds) {
        UIComponent.registerComponent()

        app
            .addSystem(UpdateWindowManagerSystem.self, on: .preUpdate)
            .addSystem(UIComponentSystem.self)
            .insertResource(UIDrawPendingViews(views: []))
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
            window.minSize = windowSettings.minimumSize
            window.frame = Rect(origin: .zero, size: windowSettings.minimumSize)
            window.setWindowMode(
                windowSettings.windowMode == .fullscreen ? .fullscreen : .windowed
            )
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

@System
@inline(__always)
@MainActor
func UpdateWindowManager(
    _ context: WorldUpdateContext,
    _ windowManager: Res<WindowManagerResource>,
    _ pendingViews: ResMut<UIDrawPendingViews>,
    _ input: Res<Input>,
    _ deltaTime: Res<DeltaTime>
) async {
    let windowManager = windowManager.windowManager
    let deltaTime = deltaTime.deltaTime
    let windows = windowManager.windows
    for window in windows {
        let menuBuilder = windowManager.menuBuilder(for: window)
        menuBuilder?.updateIfNeeded()
        
        for event in input.eventsPool where event.window == window.id {
            window.sendEvent(event)
        }

        await window.internalUpdate(deltaTime)
        if window.canDraw {
            pendingViews.views.append(window)
        }
    }
}

struct UIDrawPendingViews: Resource {
    var views: [UIView]
}
