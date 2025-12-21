//
//  UIRenderNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 19.12.2025.
//

import AdaECS
import AdaRender
import AdaUtils
import Math

// TODO: - Avoid redrawing if nothing changed.

/// Resource that holds the UI view uniform for rendering.
/// Uses an orthographic projection with origin at top-left corner.
public struct UIViewUniform: Resource {
    public var viewProjectionMatrix: Transform3D = .identity

    public init() {}
}

public struct UIRenderNode: RenderNode {
    /// Input slots of render node.
    public enum InputNode {
        public static let view: RenderSlot.Label = "view"
    }

    @Query<
        Entity,
        Camera,
        RenderViewTarget,
        GlobalViewUniform
    >
    private var query

    @Res<RenderItems<UITransparentRenderItem>>
    private var renderItems

    @ResMut<UIViewUniform>
    private var uiViewUniform

    @Res<RenderDeviceHandler>
    private var renderDevice

    public init() {}

    public let inputResources: [RenderSlot] = [
        RenderSlot(name: InputNode.view, kind: .entity)
    ]

    public func update(from world: World) {
        query.update(from: world)
        _renderItems.update(from: world)
        _uiViewUniform.update(from: world)
        _renderDevice.update(from: world)
    }

    public func execute(
        context: inout Context,
        renderContext: AdaRender.RenderContext
    ) async throws -> [AdaRender.RenderSlotValue] {
        guard let view = context.viewEntity else {
            return []
        }

        try query.forEach { entity, camera, target, cameraUniform in
            if entity != view {
                return
            }

            let commandBuffer = renderContext.commandQueue.makeCommandBuffer()

            guard let texture = target.mainTexture else {
                return
            }

            // Get viewport size
            let viewportSize = camera.viewport.rect.size

            // Create UI-specific orthographic projection with origin at top-left
            let uiProjection = Transform3D.createUIProjection(
                width: viewportSize.width,
                height: viewportSize.height,
                scaleFactor: texture.scaleFactor
            )

            // Update the UI view uniform buffer
            let uiViewUniform = makeUIViewUniform(
                projection: uiProjection
            )

            let renderPass = commandBuffer.beginRenderPass(
                RenderPassDescriptor(
                    label: "UI Render Pass",
                    colorAttachments: [
                        .init(
                            texture: texture,
                            operation: OperationDescriptor(
                                loadAction: .load,  // Load existing content (don't clear)
                                storeAction: .store
                            ),
                            clearColor: .clear
                        )
                    ],
                    depthStencilAttachment: nil
                )
            )

            // Set the UI view uniform (not the camera's uniform)
            renderPass.setVertexBuffer(uiViewUniform, index: GlobalBufferIndex.viewUniform)
            renderPass.setViewport(camera.viewport.rect)

            try renderItems.render(with: renderPass, world: context.world, view: view)

            renderPass.endRenderPass()
            commandBuffer.commit()
        }

        return []
    }

    private func makeUIViewUniform(
        projection: Transform3D
    ) -> GlobalViewUniform {
        uiViewUniform.viewProjectionMatrix = projection

        // Update the uniform buffer with UI projection
        let uniform = GlobalViewUniform(
            projectionMatrix: projection,
            viewProjectionMatrix: projection,
            viewMatrix: .identity
        )

        return uniform
    }
}

public extension Transform3D {
    /// Creates an orthographic projection matrix for UI rendering.
    /// Origin is at top-left corner, Y increases downward.
    /// - Parameters:
    ///   - width: Viewport width in points.
    ///   - height: Viewport height in points.
    ///   - scaleFactor: Scale factor for HiDPI displays.
    /// - Returns: Orthographic projection matrix.
    static func createUIProjection(
        width: Float,
        height: Float,
        scaleFactor: Float = 1.0
    ) -> Transform3D {
        // UI orthographic projection with origin at top-left
        // X: 0 to width (left to right)
        // Y: 0 to -height (top to bottom, negated in Rect.toTransform3D)
        return Transform3D.orthographic(
            left: 0,
            right: width / scaleFactor,
            top: 0,
            bottom: -height / scaleFactor,
            zNear: -1000,
            zFar: 1000
        )
    }
}
