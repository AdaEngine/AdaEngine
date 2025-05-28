//
//  CameraSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

@_spi(Internal) import AdaECS
@_spi(Internal) import AdaRender

// FIXME: Currently we render on window directly
// TODO: Move window info to ECS system

/// System for updating cameras data on scene.
@System(dependencies: [
    .after(ScriptComponentUpdateSystem.self)
])
public struct CameraSystem: Sendable {

    @Query<Entity, Ref<Camera>, GlobalTransform>
    private var query

    public init(world: World) { }

    public func update(context: UpdateContext) {
        self.query.forEach { entity, camera, globalTransform in
            let viewMatrix = globalTransform.matrix.inverse
            camera.viewMatrix = viewMatrix

            context.scheduler.addTask { @MainActor in
                self.updateViewportSizeIfNeeded(for: &camera.wrappedValue, window: context.scene?.window)
                self.updateProjectionMatrix(for: &camera.wrappedValue)
                self.updateFrustum(for: &camera.wrappedValue)

                entity.components += GlobalViewUniform(
                    projectionMatrix: camera.computedData.projectionMatrix,
                    viewProjectionMatrix: camera.computedData.projectionMatrix * viewMatrix,
                    viewMatrix: camera.viewMatrix
                )
            }
        }
    }

    @MainActor
    private func updateViewportSizeIfNeeded(
        for camera: inout Camera, 
        window: UIWindow?
    ) {
        switch camera.renderTarget {
        case .window(let windowRef):
            camera.renderTarget = .window(windowRef)
            camera.computedData.targetScaleFactor = window?.screen?.scale ?? 1

            let windowSize = window?.frame.size ?? .zero

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

/// Exctract cameras to RenderWorld for future rendering.
@System(dependencies: [
    .after(CameraSystem.self)
])
public struct ExtractCameraSystem {

    @EntityQuery(
        where: .has(Camera.self) &&
        .has(Transform.self) && 
        .has(VisibleEntities.self)
    )
    private var query

    public init(world: World) { }

    public func update(context: UpdateContext) {
        self.query.forEach { entity in
            let cameraEntity = Entity(name: "ExtractedCameraEntity")
            if let bufferSet = entity.components[GlobalViewUniformBufferSet.self],
                let uniform = entity.components[GlobalViewUniform.self]
            {

                let buffer = bufferSet.uniformBufferSet.getBuffer(
                    binding: GlobalBufferIndex.viewUniform,
                    set: 0,
                    frameIndex: RenderEngine.shared.currentFrameIndex
                )

                buffer.setData(uniform)
            }

            cameraEntity.components = entity.components
            cameraEntity.components += RenderItems<Transparent2DRenderItem>()
            cameraEntity.components.entity = cameraEntity

            context.scheduler.addTask {
                await Application.shared.renderWorld.addEntity(cameraEntity)
            }
        }
    }
}
