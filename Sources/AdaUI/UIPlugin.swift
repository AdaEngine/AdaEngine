//
//  UIPlugin.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import AdaApp
import AdaECS
@_spi(Internal) import AdaInput
import AdaUtils
import Math

public struct UIPlugin: Plugin {

    public init() { }

    public func setup(in app: AppWorlds) {
        UIComponent.registerComponent()

        app
            .addSystem(UpdateWindowManagerSystem.self, on: .preUpdate)
            .addSystem(UIComponentSystem.self)
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
            app.insertResource(PrimaryWindow(window: primaryWindow))
        } else {
            let window = UIWindow()
            window.title = windowSettings.title ?? "App"
            window.minSize = windowSettings.minimumSize
            window.frame = Rect(origin: .zero, size: windowSettings.minimumSize)
            window.setWindowMode(
                windowSettings.windowMode == .fullscreen ? .fullscreen : .windowed
            )
            window.showWindow(makeFocused: true)
            app.insertResource(PrimaryWindow(window: window))
        }
    }
}

public struct PrimaryWindow: Resource {
    public let window: UIWindow
}

public struct WindowManagerResource: Resource {
    public var windowManager: UIWindowManager

    public init(windowManager: UIWindowManager) {
        self.windowManager = windowManager
    }
}

@System
@inline(__always)
@MainActor
func UpdateWindowManager(
    _ context: inout WorldUpdateContext,
    _ windowManager: ResQuery<WindowManagerResource>,
    _ input: ResQuery<Input>,
    _ deltaTime: ResQuery<DeltaTime>
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
            var context = UIGraphicsContext(window: window)
            context.beginDraw(in: window.frame.size, scaleFactor: 1)
            window.draw(with: context)
            context.commitDraw()
        }
    }
}
