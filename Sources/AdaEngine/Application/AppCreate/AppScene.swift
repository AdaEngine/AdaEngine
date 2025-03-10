//
//  AppScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/14/22.
//

/// Describe which kind of scene will present on start.
@MainActor @preconcurrency
public protocol AppScene {
    associatedtype Body: AppScene
    var scene: Body { get }
}

// MARK: - Modifiers

public extension AppScene {
    /// Set the minimum size of the window.
    func minimumSize(width: Float, height: Float) -> some AppScene {
        return self.modifier(MinimumWindowSizeSceneModifier(size: Size(width: width, height: height)))
    }

    /// Set the window presentation mode.
    func windowMode(_ mode: UIWindow.Mode) -> some AppScene {
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
    
    /// Add new specific ``RenderWorldPlugin`` to the app.
    func renderPlugin<T: RenderWorldPlugin>(_ plugin: T) -> some AppScene {
        self.modifier(RenderWorldPluginSceneModifier(plugin: plugin))
    }
    
    /// Disable all default render plugins from app.
    func disableDefaultRenderPlugins(_ isDisable: Bool) -> some AppScene {
        self.modifier(UseDefaultRenderPlugins(isEnabled: !isDisable))
    }
    
    private func modifier<M: SceneModifier>(_ modifier: M) -> some AppScene {
        return ModifiedScene(storedScene: self, modifier: modifier)
    }
}
