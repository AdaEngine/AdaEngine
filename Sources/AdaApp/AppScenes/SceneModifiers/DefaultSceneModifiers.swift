//
//  DefaultSceneModifiers.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/9/23.
//

import AdaECS
import AdaUtils
import Math

/// Set the minimum size of presented window.
struct MinimumWindowSizeSceneModifier: SceneModifier {
    let size: Size

    func body(content: Content) -> some AppScene {
        content.updateResource(
            of: WindowSettings.self,
            keyPath: \.minimumSize,
            value: size
        )
    }
}

/// Set the window mode.
struct WindowModeSceneModifier: SceneModifier {
    let windowMode: WindowMode

    func body(content: Content) -> some AppScene {
        content.updateResource(
            of: WindowSettings.self,
            keyPath: \.windowMode,
            value: windowMode
        )
    }
}

/// Set flag if we can't create more than one window per app.
struct IsSingleWindowSceneModifier: SceneModifier {
    let isSingleWindow: Bool

    func body(content: Content) -> some AppScene {
        content.updateResource(
            of: WindowSettings.self,
            keyPath: \.isSingleWindow,
            value: isSingleWindow
        )
    }
}

/// Set the title for the window.
struct WindowTitleSceneModifier: SceneModifier {
    let title: String

    func body(content: Content) -> some AppScene {
        content.updateResource(of: WindowSettings.self, keyPath: \.title, value: title)
    }
}

/// Add plugins to app.
struct AddPluginsModifier<each T: Plugin>: SceneModifier {
    let plugins: (repeat (each T))

    func body(content: Content) -> some AppScene {
        content.transformAppWorlds { worlds in
            for plugin in repeat (each plugins) {
                worlds.addPlugin(plugin)
            }
        }
    }
}

public extension AppScene {
    /// Transform the app worlds.
    /// - Parameter transform: The transform to apply to the app worlds.
    @MainActor
    func transformAppWorlds(
        transform: @escaping @MainActor (AppWorlds) -> Void
    ) -> some AppScene {
        self.modifier(
            TransformAppWorldsModifier(
                content: self,
                block: transform
            )
        )
    }

    /// Update the resource of the app worlds.
    /// - Parameter type: The type of the resource to update.
    /// - Parameter keyPath: The key path of the resource to update.
    /// - Parameter value: The value to update the resource with.
    @MainActor
    func updateResource<T: Resource, Value>(
        of type: T.Type,
        keyPath: WritableKeyPath<T, Value>,
        value: Value
    ) -> some AppScene {
        transformAppWorlds { worlds in
            let resource = worlds.main.getRefResource(T.self)
            resource.wrappedValue[keyPath: keyPath] = value
        }
    }
}

struct TransformAppWorldsModifier<WrappedScene: AppScene>: SceneModifier, _ViewInputsViewModifier {
    let content: WrappedScene
    let block: (AppWorlds) -> Void

    func body(content: Content) -> some AppScene {
        return content
    }

    static func _makeModifier(_ modifier: _AppSceneNode<Self>, inputs: inout _SceneInputs) {
        modifier.value.block(inputs.appWorlds)
    }
}
