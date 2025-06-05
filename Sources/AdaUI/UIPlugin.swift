//
//  UIPlugin.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 19.08.2024.
//

import AdaApp
import AdaECS
import AdaUtils
import Math

public struct UIPlugin: Plugin {

    public init() { }

    public func setup(in app: AppWorlds) {
        UIComponent.registerComponent()

        app
            .addSystem(GraphicsContextInitializedSystem.self)
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

@PlainSystem
func GraphicsContextInitialized(
    _ world: World,
    _ kek: ResQuery<PrimaryWindow>
) {
    
}
