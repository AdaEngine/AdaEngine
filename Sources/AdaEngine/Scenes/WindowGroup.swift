//
//  WindowGroup.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

import AdaApp
import AdaECS
import AdaScene
import AdaUtils
import Math

/// A scene that presents a group of identically structured windows.
public struct WindowGroup<Content: View>: AppScene {
    /// Content view
    let content: Content

    /// The file path to use for the `AssetsPlugin`.
    let filePath: StaticString

    public var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(WindowGroupPlugin(content: self.content))
    }

    /// Creates a window group.
    /// - Parameter contentView: A closure that creates the content for each instance of the group.
    /// - Parameter filePath: The file path to use for the `AssetsPlugin`.
    public init(@ViewBuilder content: () -> Content, filePath: StaticString = #filePath) {
        self.content = content()
        self.filePath = filePath
    }
}

package struct WindowGroupPlugin<Content: View>: Plugin, @unchecked Sendable {
    let content: Content

    package func setup(in app: borrowing AppWorlds) {
        app.insertResource(
            InitialContainerView(view: UIContainerView(rootView: self.content))
        )
        app.addSystem(WindowGroupUpdateSystem.self, on: .startup)
        app.spawn(bundle: Camera2D())
    }
}

struct InitialContainerView: Resource {
    let view: UIView
}

@System
@MainActor
func WindowGroupUpdate(
    _ context: WorldUpdateContext,
    _ primaryWindow: ResMut<PrimaryWindow>,
    _ containerView: Res<InitialContainerView>
) {
    let view = containerView.view
    view.autoresizingRules = [.flexibleWidth, .flexibleHeight]
    primaryWindow.wrappedValue.window.addSubview(view)
}
