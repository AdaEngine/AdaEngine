//
//  AppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/14/22.
//

import Math

/// Describe which kind of scene will present on start.
@MainActor @preconcurrency
public protocol AppScene {
    associatedtype Body: AppScene
    var body: Body { get }
}

// MARK: - Modifiers

public extension AppScene {
    /// Set the minimum size of the window.
    func minimumSize(width: Float, height: Float) -> some AppScene {
        return self.modifier(MinimumWindowSizeSceneModifier(size: Size(width: width, height: height)))
    }

    /// Set the window presentation mode.
    func windowMode(_ mode: WindowMode) -> some AppScene {
        return self.modifier(WindowModeSceneModifier(windowMode: mode))
    }

    /// Set the flag which describe can we create more than one window.
    func singleWindow(_ isSingleWindow: Bool) -> some AppScene {
        return self.modifier(IsSingleWindowSceneModifier(isSingleWindow: isSingleWindow))
    }

    /// Set the window title.
    func windowTitle(_ title: String) -> some AppScene {
        self.modifier(WindowTitleSceneModifier(title: title))
    }

    /// Add new plugin for app
    func insertPlugin<T: Plugin>(_ plugin: T) -> some AppScene {
        return modifier(AddPluginModifier(plugin: plugin))
    }

    private func modifier<M: SceneModifier>(_ modifier: M) -> some AppScene {
        return ModifiedScene(storedScene: self, modifier: modifier)
    }
}
