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

/// Insert plugin to app.
struct AddPluginModifier<T: Plugin>: SceneModifier {
    let plugin: T

    func body(content: Content) -> some AppScene {
        content.transformAppWorlds { worlds in
            worlds.addPlugin(plugin)
        }
    }
}

public extension AppScene {
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

    @MainActor
    func updateResource<T: Resource, Value>(
        of type: T.Type,
        keyPath: WritableKeyPath<T, Value>,
        value: Value
    ) -> some AppScene {
        transformAppWorlds { worlds in
            guard var resource = worlds.getResource(T.self) else { return }
            resource[keyPath: keyPath] = value
            worlds.insertResource(resource)
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
