//
//  SceneView.swift
//  AdaEngine
//
//  Created by AdaEngine on 04.04.2026.
//

import AdaECS
import AdaUI
import Math

/// A view that creates a separate offscreen runtime with its own `World`, renders it
/// into a `RenderTexture`, and exposes the result as a reactive viewport embeddable
/// into the AdaUI view hierarchy.
///
/// The `setup` closure is called exactly once per `SceneView` instance after the runtime
/// is bootstrapped and the camera entity is created but before the first render tick.
/// The `content` builder receives a ``SceneViewContext`` whose ``SceneViewContext/viewport``
/// property returns a live viewport view.
///
/// ```swift
/// SceneView(setup: { world in
///     world.spawn("Player") {
///         SpriteBundle(texture: playerTexture)
///     }
/// }) { context in
///     ZStack {
///         context.viewport
///         Text("Score: \(score)")
///     }
/// }
/// ```
public struct SceneView<Content: View>: View {

    let filePath: StaticString
    let setup: @MainActor (World) -> Void
    let contentBuilder: @MainActor (SceneViewContext) -> Content

    public init(
        filePath: StaticString = #filePath,
        setup: @escaping @MainActor (World) -> Void,
        @ViewBuilder content: @escaping @MainActor (SceneViewContext) -> Content
    ) {
        self.filePath = filePath
        self.setup = setup
        self.contentBuilder = content
    }

    public var body: some View {
        OffscreenViewportContainer(
            delegateFactory: { [filePath, setup] in
                SceneViewCoordinator(filePath: filePath, setup: setup)
            },
            contentBuilder: { [contentBuilder] delegate in
                let coordinator = delegate as! SceneViewCoordinator
                let context = SceneViewContext(coordinator: coordinator)
                contentBuilder(context)
            }
        )
    }
}

// MARK: - SceneViewContext

/// Provides access to the live viewport rendered by a ``SceneView``.
@MainActor
public struct SceneViewContext {

    let coordinator: SceneViewCoordinator

    /// A view displaying the rendered scene. Embed it in `ZStack`, `VStack`,
    /// overlays, or any other AdaUI container.
    public var viewport: some View {
        OffscreenViewportView(delegate: coordinator)
    }
}
