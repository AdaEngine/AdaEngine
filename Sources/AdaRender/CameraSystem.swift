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

// FIXME: Currently we render on window directly
// TODO: Move window info to ECS system

/// System for updating cameras data on scene.
@PlainSystem
public struct CameraSystem: Sendable {

    @Query<Entity, Ref<Camera>, GlobalTransform>
    private var query

    public init(world: World) { }

    public func update(context: inout UpdateContext) {
        self.query.forEach { entity, camera, globalTransform in
            let viewMatrix = globalTransform.matrix.inverse
            camera.viewMatrix = viewMatrix

                self.updateViewportSizeIfNeeded(
                    for: &camera.wrappedValue,
                    screenScale: 2,
                    windowSize: Size(width: 800, height: 600) // FIXME: Must use actual size
                )
            self.updateProjectionMatrix(for: &camera.wrappedValue)
            self.updateFrustum(for: &camera.wrappedValue)

            entity.components += GlobalViewUniform(
                projectionMatrix: camera.computedData.projectionMatrix,
                viewProjectionMatrix: camera.computedData.projectionMatrix * viewMatrix,
                viewMatrix: camera.viewMatrix
            )
        }
    }

    private func updateViewportSizeIfNeeded(
        for camera: inout Camera, 
        screenScale: Float,
        windowSize: Size
    ) {
        switch camera.renderTarget {
        case .window(let windowRef):
            camera.renderTarget = .window(windowRef)
            camera.computedData.targetScaleFactor = screenScale

            if camera.viewport == nil {
                camera.viewport = Viewport(rect: Rect(origin: .zero, size: windowSize))
                return
            }

            if camera.viewport?.rect.size != windowSize {
                camera.viewport?.rect.size = windowSize
            }
        case .texture(let textureHandle):
            let texture = textureHandle.asset
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
    _ query: Extract<
        Query<Entity, Camera, Transform, VisibleEntities, GlobalViewUniformBufferSet, GlobalViewUniform>
    >
) {
    query.wrappedValue.forEach {
        entity, camera, transform, visibleEntities, bufferSet, uniform in

        let buffer = bufferSet.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )

        buffer.setData(uniform)

        world.spawn("ExtractedCameraEntity") {
            camera
            transform
            visibleEntities
            RenderItems<Transparent2DRenderItem>()
        }
    }
}
