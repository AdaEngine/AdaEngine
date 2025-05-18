//
//  CameraSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

@_spi(Internal) import AdaECS

// FIXME: Currently we render on window directly

/// System for updating cameras data on scene.
public struct CameraSystem: System, Sendable {

    public static let dependencies: [SystemDependency] = [.after(ScriptComponentUpdateSystem.self)]

    static let query = EntityQuery(where: .has(Camera.self) && .has(Transform.self))

    public init(world: World) { }

    public func update(context: UpdateContext) {
        context.world.performQuery(Self.query).forEach { entity in
            context.scheduler.addTask { @MainActor in
                guard var camera = entity.components[Camera.self] else {
                    return
                }

                let transform = context.world.worldTransformMatrix(for: entity)
                let viewMatrix = transform.inverse
                camera.viewMatrix = viewMatrix

                self.updateViewportSizeIfNeeded(for: &camera, window: context.scene.window)
                self.updateProjectionMatrix(for: &camera)
                self.updateFrustum(for: &camera)

                entity.components += GlobalViewUniform(
                    projectionMatrix: camera.computedData.projectionMatrix,
                    viewProjectionMatrix: camera.computedData.projectionMatrix * viewMatrix,
                    viewMatrix: camera.viewMatrix
                )
                entity.components[Camera.self] = camera
            }
        }
    }

    @MainActor
    private func updateViewportSizeIfNeeded(for camera: inout Camera, window: UIWindow?) {
        switch camera.renderTarget {
        case .window(let id):
            if id != window?.id {
                camera.renderTarget = .window(window?.id ?? .empty)
                camera.computedData.targetScaleFactor = window?.screen?.scale ?? 1
            }

            let windowSize = window?.frame.size ?? .zero

            if camera.viewport == nil {
                camera.viewport = Viewport(rect: Rect(origin: .zero, size: windowSize))
                return
            }

            if camera.viewport?.rect.size != windowSize {
                camera.viewport?.rect.size = windowSize
            }
        case .texture(let texture):
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
public struct ExtractCameraSystem: System {

    public static let dependencies: [SystemDependency] = [.after(CameraSystem.self)]

    static let query = EntityQuery(where: .has(Camera.self) && .has(Transform.self) && .has(VisibleEntities.self))

    public init(world: World) { }

    public func update(context: UpdateContext) {
        context.world.performQuery(Self.query).forEach { entity in
            context.scheduler.addTask {
                let cameraEntity = EmptyEntity()

                if
                    let bufferSet = entity.components[GlobalViewUniformBufferSet.self],
                    let uniform = entity.components[GlobalViewUniform.self] {

                    let buffer = bufferSet.uniformBufferSet.getBuffer(
                        binding: GlobalBufferIndex.viewUniform,
                        set: 0,
                        frameIndex: RenderEngine.shared.currentFrameIndex
                    )

                    buffer.setData(uniform)
                }

                cameraEntity.components = entity.components
                cameraEntity.components.entity = cameraEntity

                await Application.shared.renderWorld.addEntity(cameraEntity)
            }
        }
    }
}
