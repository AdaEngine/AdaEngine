//
//  AppScene.swift
//  
//
//  Created by v.prusakov on 6/14/22.
//

/// Describe which kind of scene will present on start.
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
    func windowMode(_ mode: Window.Mode) -> some AppScene {
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
    
    private func modifier<M: SceneModifier>(_ modifier: M) -> some AppScene {
        return ModifiedScene(storedScene: self, modifier: modifier)
    }
}
