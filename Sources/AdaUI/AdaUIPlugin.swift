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

        app.addPlugin(PrimaryWindowPlugin())
        app.addSystem(UIComponentSystem.self)
    }
}

struct PrimaryWindowPlugin: Plugin {
    func setup(in app: AppWorlds) {
        guard let windowSettings = app.getResource(WindowSettings.self) else {
            return
        }

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

public struct PrimaryWindow: Resource {
    public let window: UIWindow
}
