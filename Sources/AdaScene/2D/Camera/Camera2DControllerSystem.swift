import AdaApp
import AdaECS
import AdaRender
import AdaTransform
import AdaUtils
import Math

/// Registers ``Camera2DController`` and ``CameraTarget2D`` and runs the controller after transform propagation.
public struct Camera2DControllerPlugin: Plugin {
    public init() {}

    public func setup(in app: AppWorlds) {
        Camera2DController.registerComponent()
        CameraTarget2D.registerComponent()
        RuntimeTypeRegistry.registerComponent(Camera2DController.self, names: ["Camera2DController"])
        RuntimeTypeRegistry.registerComponent(CameraTarget2D.self, names: ["CameraTarget2D"])
        app.addSystem(Camera2DControllerSystem.self, on: .postUpdate)
    }
}

/// Runs after the followed entities have their final world transform for the frame, then publishes the camera's
/// transform and view data itself, so the frame is extracted with the camera exactly where the controller put it.
@PlainSystem(dependencies: [.after(TransformSystem.self), .after(ChildTransformSystem.self)])
public struct Camera2DControllerSystem {
    @Query<Entity, Ref<Camera2DController>, Ref<Camera>, Transform>
    private var cameras
    @Query<CameraTarget2D, GlobalTransform>
    private var targets
    @Res<DeltaTime> private var time
    @Res private var primaryWindow: PrimaryWindowId?

    public init(world _: World) {}

    @MainActor
    public func update(context _: UpdateContext) {
        var sums: [String: (x: Float, y: Float, weight: Float)] = [:]
        targets.forEach { target, global in
            guard target.weight.isFinite, target.weight > 0 else { return }
            let origin = global.matrix.origin
            guard origin.x.isFinite, origin.y.isFinite else { return }
            var entry = sums[target.group] ?? (0, 0, 0)
            entry.x += origin.x * target.weight
            entry.y += origin.y * target.weight
            entry.weight += target.weight
            sums[target.group] = entry
        }
        let delta = Double(time.deltaTime)
        // Writes that can change an entity's archetype wait until the query has finished iterating.
        var published: [(entity: Entity, transform: Transform, changed: Bool, global: GlobalTransform, uniform: GlobalViewUniform)] = []
        cameras.forEach { entity, controller, camera, transform in
            guard controller.wrappedValue.isEnabled else { return }
            var state = controller.wrappedValue
            let target = sums[state.targetGroup].map { Vector2($0.x / $0.weight, $0.y / $0.weight) }
            let output = Self.step(&state, camera: camera, transform: transform, target: target, deltaTime: delta)
            controller.wrappedValue = state

            var next = transform
            next.position = Vector3(output.position.x, output.position.y, transform.position.z)
            if let roll = output.roll { next.rotation = Quat(axis: Vector3(0, 0, 1), angle: roll) }
            // The controller runs after propagation; publish the same matrix so this frame's view is already correct.
            let global = GlobalTransform(matrix: next.matrix)
            let uniform = CameraSystem.refreshView(of: camera, globalTransform: global, primaryWindow: primaryWindow)
            published.append((entity, next, next != transform, global, uniform))
        }
        for item in published {
            if item.changed { item.entity.components[Transform.self] = item.transform }
            item.entity.components[GlobalTransform.self] = item.global
            item.entity.components += item.uniform
        }
    }

    struct Output {
        var position: Vector2
        var roll: Float?
    }

    /// One update of the controller state. Separate from the ECS plumbing so the rules can be driven directly.
    @MainActor
    static func step(
        _ state: inout Camera2DController,
        camera: Ref<Camera>,
        transform: Transform,
        target: Vector2?,
        deltaTime: Double
    ) -> Output {
        var projection = OrthographicProjection()
        if case .orthographic(let current) = camera.wrappedValue.projection { projection = current }
        let viewportSize = camera.wrappedValue.logicalViewport.rect.size
        let snapNow = !state.isInitialized || state.appliedSnapCount != state.snapCount

        // Zoom
        let wantedZoom = clampedZoom(state)
        if snapNow || !state.currentZoom.isFinite {
            state.currentZoom = wantedZoom
        } else {
            state.currentZoom += (wantedZoom - state.currentZoom) * Camera2DMath.smoothingFactor(deltaTime: deltaTime, time: state.zoomSmoothingTime)
        }
        if projection.scale != state.currentZoom {
            projection.scale = state.currentZoom
            camera.wrappedValue.projection = .orthographic(projection)
        }

        // Follow
        if !state.isInitialized, state.position == .zero { state.position = Vector2(transform.position.x, transform.position.y) }
        if let target {
            let wanted = target + state.offset
            if snapNow {
                state.position = wanted
            } else {
                let held = Camera2DMath.applyDeadZone(position: state.position, target: wanted, deadZone: state.deadZone)
                let factor = Camera2DMath.smoothingFactor(deltaTime: deltaTime, time: state.smoothingTime)
                state.position += (held - state.position) * factor
            }
        }
        state.isInitialized = true
        state.appliedSnapCount = state.snapCount

        // Limits constrain the stored position, so the camera comes back as soon as the target does.
        if state.limitsEnabled, viewportSize.width > 0, viewportSize.height > 0 {
            let extents = Camera2DMath.ViewExtents(viewportSize: viewportSize, zoom: state.currentZoom, viewportOrigin: projection.viewportOrigin)
            state.position = Camera2DMath.clamp(position: state.position, extents: extents, limitMin: state.limitMin, limitMax: state.limitMax)
        }

        // Shake sits on top of the followed position and never feeds back into it.
        if deltaTime.isFinite, deltaTime > 0 {
            state.shakeTime += deltaTime
            state.trauma = max(0, state.trauma - max(0, state.traumaDecay) * Float(deltaTime))
        }
        let shake = Camera2DMath.shake(
            trauma: state.trauma,
            time: state.shakeTime,
            frequency: state.shakeFrequency,
            maxOffset: state.shakeMaxOffset,
            maxRoll: state.shakeMaxRoll * .pi / 180
        )
        var final = state.position
        if state.snapsToPixels { final = Camera2DMath.snapToPixels(final, zoom: state.currentZoom) }
        final += shake.offset
        return Output(position: final, roll: state.shakeMaxRoll != 0 ? shake.roll : nil)
    }

    private static func clampedZoom(_ state: Camera2DController) -> Float {
        let lower = state.minZoom.isFinite && state.minZoom > 0 ? state.minZoom : 0.1
        let upper = state.maxZoom.isFinite && state.maxZoom >= lower ? state.maxZoom : lower
        let zoom = state.zoom.isFinite ? state.zoom : 1
        return min(max(zoom, lower), upper)
    }
}
