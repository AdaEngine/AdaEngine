//
//  CameraSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

import AdaAssets
@_spi(Internal) import AdaECS
import AdaTransform
import AdaUtils
import Math

// FIXME: Currently we render on window directly
// TODO: Move window info to ECS system

/// System for updating cameras data on scene.
@PlainSystem
public struct CameraSystem: Sendable {
    @Query<Entity, Ref<Camera>, GlobalTransform>
    private var query

    @Res
    private var primaryWindow: PrimaryWindowId?

    public init(world _: World) {}

    @MainActor
    public func update(context _: UpdateContext) {
        var uniforms: [(Entity, GlobalViewUniform)] = []
        self.query.forEach { entity, camera, globalTransform in
            uniforms.append((entity, Self.refreshView(of: camera, globalTransform: globalTransform, primaryWindow: primaryWindow)))
        }
        // A camera's first uniform moves it to another archetype, which must not happen while the query iterates.
        for (entity, uniform) in uniforms {
            entity.components += uniform
        }
    }

    /// Recomputes a camera's view, projection and frustum from a world transform and returns its ``GlobalViewUniform``.
    ///
    /// ``CameraSystem`` calls this for every camera at the start of a frame. A system that moves a camera after
    /// transform propagation can call it again, so that extraction sees the camera where it ended up this frame.
    /// The caller stores the result with `entity.components += uniform`, after its own query has finished iterating.
    @MainActor
    public static func refreshView(
        of camera: Ref<Camera>,
        globalTransform: GlobalTransform,
        primaryWindow: PrimaryWindowId?
    ) -> GlobalViewUniform {
        let viewMatrix = globalTransform.matrix.inverse
        camera.viewMatrix = viewMatrix
        camera.computedData.viewMatrix = viewMatrix
        self.updateViewportSizeIfNeeded(for: camera, primaryWindow: primaryWindow)
        self.updateProjectionMatrix(for: camera)
        self.updateFrustum(for: camera)

        return GlobalViewUniform(
            projectionMatrix: camera.computedData.projectionMatrix,
            viewProjectionMatrix: camera.computedData.projectionMatrix * viewMatrix,
            viewMatrix: camera.viewMatrix
        )
    }

    @MainActor
    private static func updateViewportSizeIfNeeded(
        for camera: Ref<Camera>,
        primaryWindow: PrimaryWindowId?
    ) {
        var needsUpdateProjection = false

        switch camera.renderTarget {
        case let .window(windowRef):
            guard let primaryWindow else {
                return
            }
            camera.renderTarget = .window(windowRef)

            let resolvedWindowId = windowRef.getWindowId(from: primaryWindow)
            guard
                let renderWindow = unsafe RenderEngine.shared
                    .getRenderWindow(for: resolvedWindowId)
            else {
                return
            }

            camera.computedData.targetScaleFactor = renderWindow.scaleFactor
            if camera.viewport.rect.size != renderWindow.physicalSize {
                camera.viewport.rect.size = renderWindow.physicalSize
                needsUpdateProjection = true
            }
            if camera.logicalViewport.rect.size.toSizeInt() != renderWindow.logicalSize {
                camera.logicalViewport.rect.size = renderWindow.logicalSize.toSize()
                needsUpdateProjection = true
            }

        case let .texture(textureHandle):
            let texture = textureHandle.asset.unwrap(message: "Camera render-target texture is not loaded.")
            let size = Size(width: Float(texture.width), height: Float(texture.height))

            if camera.viewport.rect.size != size {
                camera.viewport.rect.size = size
                needsUpdateProjection = true
            }

            if camera.logicalViewport.rect.size != size {
                camera.logicalViewport.rect.size = (size.asVector2 / texture.scaleFactor).asSize
                needsUpdateProjection = true
            }

            camera.computedData.targetScaleFactor = texture.scaleFactor
        }

        // A pixel-perfect camera projects its fixed resolution, not the window.
        let projectionSize = camera.wrappedValue.projectionViewportSize
        if camera.computedData.projectionViewportSize != projectionSize {
            needsUpdateProjection = true
        }

        if needsUpdateProjection {
            camera.computedData.projectionViewportSize = projectionSize
            camera.projection.updateView(
                width: projectionSize.width,
                height: projectionSize.height
            )
        }
    }

    private static func updateFrustum(for camera: Ref<Camera>) {
        camera.computedData.frustum = camera.projection
            .makeFrustum(from: camera.viewMatrix)
    }

    private static func updateProjectionMatrix(for camera: Ref<Camera>) {
        camera.computedData.projectionMatrix = camera.projection.makeClipView()
    }
}
