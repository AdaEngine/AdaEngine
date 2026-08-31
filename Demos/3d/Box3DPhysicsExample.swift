import AdaEngine
import AdaUtils
@_spi(Internal) import AdaInput
@_spi(Internal) import AdaRender
import Math

@main
struct Box3DPhysicsExample: App {
    var body: some AppScene {
        GameAppScene {
            let world = World()
            return Scene(from: world)
        }
        .addPlugins(DefaultPlugins()
            .set(Physics3DPlugin())
            .set(Box3DPhysicsDemoPlugin())
        )
        .windowMode(.windowed)
    }

    fileprivate static func makeMaterial(color: Vector4) -> PBRMaterial {
        let material = PBRMaterial()
        material.baseColorFactor = color
        return material
    }

    fileprivate static func makeBoxMesh(name: String, size: Vector3) -> Mesh {
        let device = unsafe RenderEngine.shared.renderDevice
        var descriptor = MeshDescriptor(name: name)
        let half = size / 2

        let positions: [Vector3] = [
            [-half.x, -half.y,  half.z], [ half.x, -half.y,  half.z], [ half.x,  half.y,  half.z], [-half.x,  half.y,  half.z],
            [-half.x, -half.y, -half.z], [ half.x, -half.y, -half.z], [ half.x,  half.y, -half.z], [-half.x,  half.y, -half.z],
            [-half.x,  half.y,  half.z], [ half.x,  half.y,  half.z], [ half.x,  half.y, -half.z], [-half.x,  half.y, -half.z],
            [-half.x, -half.y,  half.z], [ half.x, -half.y,  half.z], [ half.x, -half.y, -half.z], [-half.x, -half.y, -half.z],
            [ half.x, -half.y,  half.z], [ half.x,  half.y,  half.z], [ half.x,  half.y, -half.z], [ half.x, -half.y, -half.z],
            [-half.x, -half.y,  half.z], [-half.x,  half.y,  half.z], [-half.x,  half.y, -half.z], [-half.x, -half.y, -half.z]
        ]

        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer([
            [0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1],
            [0, 0, -1], [0, 0, -1], [0, 0, -1], [0, 0, -1],
            [0, 1, 0], [0, 1, 0], [0, 1, 0], [0, 1, 0],
            [0, -1, 0], [0, -1, 0], [0, -1, 0], [0, -1, 0],
            [1, 0, 0], [1, 0, 0], [1, 0, 0], [1, 0, 0],
            [-1, 0, 0], [-1, 0, 0], [-1, 0, 0], [-1, 0, 0]
        ])
        descriptor.indicies = [
            0, 1, 2, 2, 3, 0,
            4, 6, 5, 6, 4, 7,
            8, 9, 10, 10, 11, 8,
            12, 14, 13, 14, 12, 15,
            16, 17, 18, 18, 19, 16,
            20, 22, 21, 22, 20, 23
        ]

        return Mesh.generate(from: [descriptor], renderDevice: device)
    }

    fileprivate static func makeSphereMesh(name: String, radius: Float, segments: Int, rings: Int) -> Mesh {
        let device = unsafe RenderEngine.shared.renderDevice
        var descriptor = MeshDescriptor(name: name)
        var positions: [Vector3] = []
        var normals: [Vector3] = []
        var indices: [UInt32] = []

        for ring in 0...rings {
            let v = Float(ring) / Float(rings)
            let theta = v * .pi
            let y = Math.cos(theta)
            let ringRadius = Math.sin(theta)

            for segment in 0...segments {
                let u = Float(segment) / Float(segments)
                let phi = u * .pi * 2
                let normal: Vector3 = [
                    ringRadius * Math.cos(phi),
                    y,
                    ringRadius * Math.sin(phi)
                ]
                normals.append(normal)
                positions.append(normal * radius)
            }
        }

        let stride = segments + 1
        for ring in 0..<rings {
            for segment in 0..<segments {
                let current = UInt32(ring * stride + segment)
                let next = UInt32((ring + 1) * stride + segment)
                indices.append(contentsOf: [
                    current,
                    next,
                    current + 1,
                    current + 1,
                    next,
                    next + 1
                ])
            }
        }

        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.indicies = indices

        return Mesh.generate(from: [descriptor], renderDevice: device)
    }
}

private struct Box3DPhysicsDemoPlugin: Plugin {
    func setup(in app: AppWorlds) {
        app.addSystem(Box3DPhysicsDemoSetupSystem.self, on: .startup)
    }
}

@Component
private struct Box3DGrabbable {
    let pickingRadius: Float
}

@System
@MainActor
func Box3DPhysicsDemoSetup(_ commands: Commands) {
    commands.spawn("Camera", bundle:
        PerspectiveCameraBundle(
            camera: Camera(window: .primary),
            transform: Transform(
                rotation: Quat.euler([0.35, 0, 0]),
                position: [0, 5, -14]
            )
        )
    )
    .insert(ScriptableComponents(scripts: [Box3DFlyCamera()]))

    let floorMaterial = Box3DPhysicsExample.makeMaterial(color: [0.18, 0.32, 0.26, 1])
    let platformMesh = Box3DPhysicsExample.makeBoxMesh(name: "Platform", size: [14, 0.5, 14])
    commands.spawn("Static platform") {
        Mesh3DComponent(
            mesh: platformMesh,
            materials: [floorMaterial]
        )
        PhysicsBody3DComponent(
            shapes: [Shape3DResource.generateBox(width: 14, height: 0.5, depth: 14)],
            mode: .static
        )
        Transform(position: [0, -0.25, 0])
    }

    let cubeMesh = Box3DPhysicsExample.makeBoxMesh(name: "Box3D Cube", size: [1, 1, 1])
    let sphereMesh = Box3DPhysicsExample.makeSphereMesh(name: "Box3D Sphere", radius: 0.5, segments: 24, rings: 12)
    let colors: [Vector4] = [
        [0.95, 0.32, 0.24, 1],
        [0.25, 0.62, 0.96, 1],
        [0.94, 0.74, 0.25, 1],
        [0.48, 0.86, 0.42, 1],
        [0.76, 0.45, 0.96, 1]
    ]

    let positions: [Vector3] = [
        [-2.8, 7.5, 0],
        [-1.4, 9.0, 0.6],
        [0.0, 10.5, -0.4],
        [1.4, 12.0, 0.8],
        [2.8, 13.5, -0.2]
    ]

    for index in positions.indices {
        let isSphere = index % 2 == 1
        let material = Box3DPhysicsExample.makeMaterial(color: colors[index])
        commands.spawn(isSphere ? "Dynamic sphere \(index)" : "Dynamic cube \(index)") {
            Mesh3DComponent(
                mesh: isSphere ? sphereMesh : cubeMesh,
                materials: [material]
            )
            PhysicsBody3DComponent(
                shapes: [
                    isSphere
                        ? Shape3DResource.generateSphere(radius: 0.5)
                        : Shape3DResource.generateBox(width: 1, height: 1, depth: 1)
                ],
                mass: 1,
                material: PhysicsMaterial.generate(friction: 0.55, restitution: 0.18, density: 1),
                mode: .dynamic
            )
            Box3DGrabbable(pickingRadius: isSphere ? 0.5 : 0.87)
            Transform(
                rotation: Quat.euler([Float(index) * 0.21, Float(index) * 0.37, 0]),
                position: positions[index]
            )
        }
    }
}

final class Box3DFlyCamera: ScriptableObject, @unchecked Sendable {
    @RequiredComponent var cameraTransform: Transform
    @RequiredComponent var camera: Camera

    var speed: Float = 7.0
    var sensitivity: Float = 5.0
    var grabResponse: Float = 12.0
    var throwSpeed: Float = 10.0

    private var lastMousePosition: Vector2?
    private var rotation: Vector3 = [0.35, 0, 0]
    private weak var grabbedEntity: Entity?
    private var grabDistance: Float = 0
    private var previousGrabTarget: Vector3?
    private var grabVelocity: Vector3 = .zero
    private var wasLeftMousePressed = false

    private var cameraRotation: Quat {
        let pitch = Transform3D.identity.rotate(angle: .radians(rotation.x), axis: .right)
        let yaw = Transform3D.identity.rotate(angle: .radians(rotation.y), axis: .up)
        return Quat(rotationMatrix: yaw * pitch)
    }

    override func update(context: ScriptableObjectContext) {
        let deltaTime = context.deltaTime
        let input = context.input
        let dt = Float(deltaTime)
        var direction: Vector3 = .zero

        if input.isKeyPressed(.w) { direction.z += 1 }
        if input.isKeyPressed(.s) { direction.z -= 1 }
        if input.isKeyPressed(.a) { direction.x -= 1 }
        if input.isKeyPressed(.d) { direction.x += 1 }
        if input.isKeyPressed(.e) { direction.y += 1 }
        if input.isKeyPressed(.q) { direction.y -= 1 }
        if input.isKeyPressed(.m) {
            var options = context.resource(PhysicsDebugOptions.self) ?? []
            options.formUnion([.showPhysicsShapes, .showBoundingBoxes])
            context.setResource(options)
        }

        if direction != .zero {
            let rotatedDirection = (Transform3D(quat: cameraRotation) * Vector4(direction.normalized, 1)).xyz
            cameraTransform.position += rotatedDirection * (speed * dt)
        }

        if input.isMouseButtonPressed(.right) {
            let currentMousePosition = input.getMousePosition()

            if let lastMousePosition {
                let delta = currentMousePosition - lastMousePosition
                self.rotation.y += delta.x * sensitivity * dt
                self.rotation.x += delta.y * sensitivity * dt
                self.rotation.x = clamp(rotation.x, -1.5, 1.5)
                cameraTransform.rotation = cameraRotation
            }

            lastMousePosition = currentMousePosition
        } else {
            lastMousePosition = nil
        }

        updateGrab(context: context, input: input, deltaTime: dt)
    }

    private func updateGrab(context: ScriptableObjectContext, input: Input, deltaTime: Float) {
        let isLeftMousePressed = input.isMouseButtonPressed(.left)
        defer { wasLeftMousePressed = isLeftMousePressed }

        guard let ray = mouseRay(context: context, input: input) else {
            if !isLeftMousePressed, wasLeftMousePressed {
                releaseGrab(ray: nil)
            }
            return
        }

        if isLeftMousePressed, !wasLeftMousePressed {
            beginGrab(context: context, ray: ray)
        }

        if isLeftMousePressed {
            moveGrabbedEntity(along: ray, deltaTime: deltaTime)
        } else if wasLeftMousePressed {
            releaseGrab(ray: ray)
        }
    }

    private func mouseRay(context: ScriptableObjectContext, input: Input) -> Ray? {
        guard let cameraGlobalTransform = context.component(GlobalTransform.self) else {
            return nil
        }

        var mousePosition = input.getMousePosition()
        mousePosition.y = camera.logicalViewport.rect.height - mousePosition.y

        return camera.viewportToWorld(
            cameraGlobalTransform: cameraGlobalTransform.matrix,
            point: mousePosition
        )
    }

    private func beginGrab(context: ScriptableObjectContext, ray: Ray) {
        let query = EntityQuery(
            where: .has(Box3DGrabbable.self)
                && .has(PhysicsBody3DComponent.self)
                && .has(GlobalTransform.self)
        )
        var closestEntity: Entity?
        var closestDistance = Float.greatestFiniteMagnitude

        for candidate in context.entities(matching: query) {
            guard
                let grabbable = candidate.components[Box3DGrabbable.self],
                let transform = candidate.components[GlobalTransform.self],
                let physicsBody = candidate.components[PhysicsBody3DComponent.self],
                case .dynamic = physicsBody.mode
            else {
                continue
            }

            let centerOffset = transform.matrix.origin - ray.origin
            let projectedDistance = centerOffset.dot(ray.direction)
            guard projectedDistance > 0, projectedDistance < 40 else {
                continue
            }

            let perpendicularDistanceSquared = centerOffset.squaredLength - projectedDistance * projectedDistance
            let radiusSquared = grabbable.pickingRadius * grabbable.pickingRadius
            guard perpendicularDistanceSquared <= radiusSquared else {
                continue
            }

            let entryDistance = projectedDistance - Math.sqrt(radiusSquared - perpendicularDistanceSquared)
            if entryDistance < closestDistance {
                closestEntity = candidate
                closestDistance = entryDistance
                grabDistance = projectedDistance
            }
        }

        guard let closestEntity, var physicsBody = closestEntity.components[PhysicsBody3DComponent.self] else {
            return
        }

        physicsBody.gravityScale = 0
        physicsBody.clearForces()
        closestEntity.components += physicsBody
        grabbedEntity = closestEntity
        previousGrabTarget = ray.point(in: grabDistance)
        grabVelocity = .zero
    }

    private func moveGrabbedEntity(along ray: Ray, deltaTime: Float) {
        guard
            let grabbedEntity,
            var physicsBody = grabbedEntity.components[PhysicsBody3DComponent.self]
        else {
            clearGrabState()
            return
        }

        let target = ray.point(in: grabDistance)
        let currentPosition = physicsBody.worldCenter
        let targetVelocity = (target - currentPosition) * grabResponse
        physicsBody.gravityScale = 0
        physicsBody.linearVelocity = clamped(targetVelocity, maximumLength: 30)
        physicsBody.angularVelocity *= Swift.max(0, 1 - 8 * deltaTime)
        grabbedEntity.components += physicsBody

        if let previousGrabTarget, deltaTime > 0 {
            let instantaneousVelocity = (target - previousGrabTarget) / deltaTime
            grabVelocity = grabVelocity * 0.65 + instantaneousVelocity * 0.35
        }
        previousGrabTarget = target
    }

    private func releaseGrab(ray: Ray?) {
        if let grabbedEntity, var physicsBody = grabbedEntity.components[PhysicsBody3DComponent.self] {
            let forwardVelocity = (ray?.direction ?? .zero) * throwSpeed
            physicsBody.gravityScale = 1
            physicsBody.linearVelocity = clamped(grabVelocity + forwardVelocity, maximumLength: 25)
            grabbedEntity.components += physicsBody
        }

        clearGrabState()
    }

    private func clearGrabState() {
        grabbedEntity = nil
        grabDistance = 0
        previousGrabTarget = nil
        grabVelocity = .zero
    }

    private func clamped(_ vector: Vector3, maximumLength: Float) -> Vector3 {
        guard vector.squaredLength > maximumLength * maximumLength else {
            return vector
        }

        return vector.normalized * maximumLength
    }
}
