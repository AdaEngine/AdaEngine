@_spi(Internal) import AdaEngine
import AdaEngineEmbeddable
import Math

/// Adapts spatial input to the existing viewport gizmo. Shape, color, drawing and drag math are shared.
@MainActor
final class EditorVRGizmoController {
    private var handles: [EditorTransformGizmo.Handle: Entity.ID] = [:]
    private var outline: [Entity.ID] = []
    private var ownerID: Entity.ID?
    private var tool: EditorSceneViewportTool?
    private var grab: Grab?
    private var previousInteractors: Set<SpatialInteractor> = []
    private var cube: Mesh?
    private struct Grab {
        let interactor: SpatialInteractor
        let startPose: Vector3
        let camera: Transform3D
        var drag: EditorTransformGizmo.Drag
        var result: Transform
    }

    func reset(in world: World?) {
        if let world {
            for id in Array(handles.values) + outline { world.getEntityByID(id)?.isActive = false }
        } else {
            handles.removeAll()
            outline.removeAll()
        }
        ownerID = nil
        tool = nil
        grab = nil
        previousInteractors.removeAll()
    }

    func prepareInput(
        in world: World,
        viewport: EditorSceneViewportModel,
        activeTool: EditorSceneViewportTool,
        camera: EditorSceneViewportModel.CameraState,
        size: Size
    ) {
        guard var input = world.getResource(SpatialInput.self) else {
            return
        }
        let current = Set(input.grips.map(\.interactor))
        defer { previousInteractors = current }
        if var grab {
            if let grip = input.grips.first(where: { $0.interactor == grab.interactor }) {
                let delta = (grab.camera.inverse * Vector4(grip.pose.origin - grab.startPose, 0)).xyz
                let pixels = Vector2(delta.x, -delta.y) / grab.drag.gizmo.worldUnitsPerPixel
                grab.result = grab.drag.updated(at: grab.drag.start + pixels)
                self.grab = grab
                input.grips.removeAll { $0.interactor == grab.interactor }
                world.insertResource(input)
            } else {
                self.grab = nil
            }
            return
        }
        guard world.getResource(SpatialSelection.self)?.isGrabbed != true,
            let definition = definition(in: world, viewport: viewport, tool: activeTool, camera: camera, size: size),
            let id = viewport.selectedEditorID, let owner = viewport.runtimeEntity(for: id), let transform = owner.components[Transform.self]
        else {
            return
        }
        for grip in input.grips where !previousInteractors.contains(grip.interactor) {
            guard let point = selectionPoint(grip, gizmo: definition, camera: camera.transform), let handle = definition.hitTest(point) else { continue }
            grab = Grab(
                interactor: grip.interactor,
                startPose: grip.pose.origin,
                camera: camera.transform.matrix,
                drag: EditorTransformGizmo.Drag(gizmo: definition, handle: handle, start: point, transform: transform),
                result: transform
            )
            input.grips.removeAll { $0.interactor == grip.interactor }
            world.insertResource(input)
            break
        }
    }

    func consume(in world: World, viewport: EditorSceneViewportModel, activeTool: EditorSceneViewportTool) {
        guard let grab, let id = viewport.selectedEditorID, let owner = viewport.runtimeEntity(for: id) else {
            return
        }
        viewport.beginSpatialTransform(editorID: id)
        viewport.updateSpatialTransform(grab.result, editorID: id)
        world.insertResource(SpatialSelection(entityID: owner.id, isGrabbed: true))
    }

    func drawings(
        in world: World,
        viewport: EditorSceneViewportModel,
        activeTool: EditorSceneViewportTool,
        camera: EditorSceneViewportModel.CameraState,
        size: Size
    ) -> [ImmersiveOverlayDrawing] {
        guard let definition = definition(in: world, viewport: viewport, tool: activeTool, camera: camera, size: size) else {
            return []
        }
        return EditorTransformGizmo.Handle.allCases.compactMap { handle in
            guard let id = handles[handle], id >= 0 else {
                return nil
            }
            var context = UIGraphicsContext()
            definition.draw(in: &context, highlighted: grab?.drag.handle, only: handle)
            guard !context.getDrawCommands().isEmpty else {
                return nil
            }
            return ImmersiveOverlayDrawing(context: context, depth: definition.depth, trackingIdentifier: UInt64(id) + 1)
        }
    }

    func definition(
        in world: World,
        viewport: EditorSceneViewportModel,
        tool: EditorSceneViewportTool,
        camera: EditorSceneViewportModel.CameraState,
        size: Size
    ) -> EditorTransformGizmo? {
        guard let id = viewport.selectedEditorID, let owner = viewport.runtimeEntity(for: id), owner.isActive,
            let transform = owner.components[Transform.self]
        else {
            return nil
        }
        return EditorTransformGizmo(tool: tool, transform: transform, parent: Self.parentMatrix(owner), camera: camera, size: size, is2D: false, screenScale: Self.screenScale(for: size))
    }

    /// Immersive eye targets use display pixels, so a desktop-sized handle is too small.
    /// Keep the axes near ten percent of the smaller eye dimension, with a 200-pixel minimum.
    static func screenScale(for size: Size) -> Float {
        max(2.5, min(size.width, size.height) / 800)
    }

    private func selectionPoint(_ grip: SpatialGrip, gizmo: EditorTransformGizmo, camera: Transform) -> Vector2? {
        let worldPoint: Vector3
        if let ray = grip.ray {
            let normal = camera.matrix.z.xyz.normalized
            let divisor = ray.direction.dot(normal)
            guard abs(divisor) > 0.00001 else {
                return nil
            }
            let distance = (gizmo.origin - ray.origin).dot(normal) / divisor
            guard distance >= 0 else {
                return nil
            }
            worldPoint = ray.origin + ray.direction * distance
        } else {
            let normal = camera.matrix.z.xyz.normalized
            guard abs((grip.pose.origin - gizmo.origin).dot(normal)) < 0.06 else {
                return nil
            }
            worldPoint = grip.pose.origin
        }
        return EditorTransformGizmo.project(worldPoint, matrix: gizmo.viewProjection, size: gizmo.size)
    }

    func update(in world: World, viewport: EditorSceneViewportModel, activeTool: EditorSceneViewportTool) {
        guard let editorID = viewport.selectedEditorID, let owner = viewport.runtimeEntity(for: editorID),
            let local = owner.components[Transform.self], let device = unsafe RenderEngine.shared?.renderDevice
        else {
            reset(in: world)
            return
        }
        if ownerID != owner.id || tool != activeTool {
            reset(in: world)
            ownerID = owner.id
            tool = activeTool
            if handles.isEmpty {
                // Stable tracking IDs only. Visible feedback comes entirely from EditorTransformGizmo.draw.
                for handle in EditorTransformGizmo.Handle.allCases {
                    handles[handle] = world.spawn("VR Gizmo \(handle.rawValue)") { Transform() }.id
                }
            }
            if cube == nil { cube = Mesh.generateCube(renderDevice: device) }
            if outline.isEmpty, let cube {
                let material = Self.material([0.15, 0.5, 1])
                for index in 0..<12 {
                    outline.append(
                        world.spawn("VR Selection Edge \(index)") {
                            Transform()
                            Mesh3DComponent(mesh: cube, materials: [material], castShadows: false, receiveShadows: false)
                            Visibility.visible
                        }.id
                    )
                }
            }
        }
        // Reuse feedback entities across selection/tool/document changes. Render extraction can
        // still retain mesh component references; avoid deleting their chunk storage mid-frame.
        for id in outline { world.getEntityByID(id)?.isActive = true }
        for id in handles.values { world.getEntityByID(id)?.isActive = activeTool != .select }
        let matrix = Self.parentMatrix(owner) * local.matrix
        let bounds = owner.components[SpatialGrabbable.self] ?? SpatialGrabbable(halfExtents: [0.15, 0.15, 0.15])
        let half = bounds.halfExtents
        var edge = 0
        for axis in 0..<3 {
            let other = (axis + 1) % 3
            let last = (axis + 2) % 3
            for a: Float in [-1, 1] {
                for b: Float in [-1, 1] where edge < outline.count {
                    var point = bounds.center
                    point[other] += a * half[other]
                    point[last] += b * half[last]
                    var thickness = Vector3(0.004)
                    thickness[axis] = half[axis] * 2 + 0.004
                    let edgeMatrix = matrix * Transform(scale: thickness, position: point).matrix
                    world.getEntityByID(outline[edge])?.components[Transform.self] = Self.decompose(edgeMatrix)
                    edge += 1
                }
            }
        }
    }

    private static func decompose(_ matrix: Transform3D) -> Transform {
        let scale = matrix.scale
        var rotation = matrix
        for column in 0..<3 where scale[column] > 0.00001 {
            for row in 0..<3 { rotation[column, row] /= scale[column] }
        }
        return Transform(rotation: rotation.rotation.normalized, scale: scale, position: matrix.origin)
    }

    private static func parentMatrix(_ entity: Entity) -> Transform3D {
        var matrix = Transform3D.identity
        var parent = entity.parent
        while let value = parent {
            matrix = (value.components[Transform.self]?.matrix ?? .identity) * matrix
            parent = value.parent
        }
        return matrix
    }

    static func material(_ color: Vector3) -> PBRMaterial {
        let material = PBRMaterial()
        material.baseColorFactor = Vector4(color, 1)
        material.emissiveFactor = color
        material.emissiveStrength = 1
        material.metallicFactor = 0
        material.roughnessFactor = 1
        material.doubleSided = true
        return material
    }
}
