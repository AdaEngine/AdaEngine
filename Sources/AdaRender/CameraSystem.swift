//
//  CameraSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

@_spi(Internal) import AdaECS
import AdaTransform
import AdaUtils
import Math
import AdaAssets

// FIXME: Currently we render on window directly
// TODO: Move window info to ECS system

/// System for updating cameras data on scene.
@PlainSystem
public struct CameraSystem: Sendable {

    @Query<Entity, Ref<Camera>, GlobalTransform>
    private var query

    @Res
    private var primaryWindow: PrimaryWindowId?

    public init(world: World) { }

    @MainActor
    public func update(context: UpdateContext) {
        self.query.forEach { entity, camera, globalTransform in
            let viewMatrix = globalTransform.matrix.inverse
            camera.viewMatrix = viewMatrix
            self.updateViewportSizeIfNeeded(for: camera)
            self.updateProjectionMatrix(for: &camera.wrappedValue)
            self.updateFrustum(for: &camera.wrappedValue)

            entity.components += GlobalViewUniform(
                projectionMatrix: camera.computedData.projectionMatrix,
                viewProjectionMatrix: camera.computedData.projectionMatrix * viewMatrix,
                viewMatrix: camera.viewMatrix
            )
        }
    }

    @MainActor
    private func updateViewportSizeIfNeeded(
        for camera: Ref<Camera>
    ) {
        switch camera.renderTarget {
        case .window(let windowRef):
            guard let primaryWindow else { return }
            camera.renderTarget = .window(windowRef)

            guard let renderWindow = RenderEngine.shared
                .getRenderWindow(for: windowRef.getWindowId(from: primaryWindow))
            else {
                return
            }

            camera.computedData.targetScaleFactor = renderWindow.scaleFactor

            if camera.viewport == nil {
                camera.viewport = Viewport(rect: Rect(origin: .zero, size: renderWindow.physicalSize))
                return
            }

            if camera.viewport?.rect.size != renderWindow.physicalSize {
                camera.viewport?.rect.size = renderWindow.physicalSize
            }
        case .texture(let textureHandle):
            let texture = textureHandle.asset!
            let size = Size(width: Float(texture.width), height: Float(texture.height))

            if camera.viewport == nil {
                camera.viewport = Viewport(rect: Rect(origin: .zero, size: size))
                return
            }

            if camera.viewport?.rect.size != size {
                camera.viewport?.rect.size = size
            }

            camera.computedData.targetScaleFactor = texture.scaleFactor
        }
    }

    private func updateFrustum(for camera: inout Camera) {
        camera.computedData.frustum = Frustum.make(from: camera.computedData.projectionMatrix * camera.viewMatrix)
    }

    // TODO: Not efficient?
    private func updateProjectionMatrix(for camera: inout Camera) {
        let viewportSize = camera.viewport?.rect.size ?? .zero

        let projection: Transform3D
        let aspectRation = viewportSize.width / viewportSize.height

        let scale = camera.orthographicScale
        let near = camera.near
        let far = camera.far

        switch camera.projection {
        case .orthographic:
            projection = Transform3D.orthographic(
                left: -aspectRation * scale,
                right: aspectRation * scale,
                top: scale,
                bottom: -scale,
                zNear: near,
                zFar: far
            )
        case .perspective:
            projection = Transform3D.perspective(
                fieldOfView: camera.fieldOfView,
                aspectRatio: aspectRation,
                zNear: near,
                zFar: far
            )
        }

        camera.computedData.projectionMatrix = projection
    }
}

@System
@inline(__always)
public func ExtractCamera(
    _ world: World,
    _ commands: Commands,
    _ query: Extract<
        Query<Camera, Transform, VisibleEntities, GlobalViewUniformBufferSet, GlobalViewUniform>
    >
) {
    query.wrappedValue.forEach {
        camera, transform,
        visibleEntities, bufferSet, uniform in
        let buffer = bufferSet.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        buffer.setData(uniform)
        commands.spawn("ExtractedCameraEntity") {
            camera
            transform
            visibleEntities
            uniform
            bufferSet
            RenderViewTarget()
            RenderItems<Transparent2DRenderItem>()
        }
    }
}
