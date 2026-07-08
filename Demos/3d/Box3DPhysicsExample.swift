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
            Transform(
                rotation: Quat.euler([Float(index) * 0.21, Float(index) * 0.37, 0]),
                position: positions[index]
            )
        }
    }
}

final class Box3DFlyCamera: ScriptableObject, @unchecked Sendable {

    @RequiredComponent var cameraTransform: Transform

    var speed: Float = 7.0
    var sensitivity: Float = 5.0

    private var lastMousePosition: Vector2?
    private var rotation: Vector3 = [0.35, 0, 0]

    private var cameraRotation: Quat {
        let pitch = Transform3D.identity.rotate(angle: .radians(rotation.x), axis: .right)
        let yaw = Transform3D.identity.rotate(angle: .radians(rotation.y), axis: .up)
        return Quat(rotationMatrix: yaw * pitch)
    }

    override func update(_ deltaTime: AdaUtils.TimeInterval) {
        let dt = Float(deltaTime)
        var direction: Vector3 = .zero

        if input.isKeyPressed(.w) { direction.z += 1 }
        if input.isKeyPressed(.s) { direction.z -= 1 }
        if input.isKeyPressed(.a) { direction.x -= 1 }
        if input.isKeyPressed(.d) { direction.x += 1 }
        if input.isKeyPressed(.e) { direction.y += 1 }
        if input.isKeyPressed(.q) { direction.y -= 1 }
        if input.isKeyPressed(.m) {
            world?.getRefResource(PhysicsDebugOptions.self).wrappedValue.formUnion([.showPhysicsShapes, .showBoundingBoxes])
        }

        if direction != .zero {
            let rotatedDirection = (Transform3D(quat: cameraRotation) * Vector4(direction.normalized, 1)).xyz
            cameraTransform.position += rotatedDirection * (speed * dt)
        }

        if input.isMouseButtonPressed(.left) {
            let currentMousePosition = input.getMousePosition()

            if let lastMousePosition {
                let delta = currentMousePosition - lastMousePosition
                self.rotation.y += delta.x * sensitivity * dt
                self.rotation.x += delta.y * sensitivity * dt
                cameraTransform.rotation = cameraRotation
            }

            lastMousePosition = currentMousePosition
        } else {
            lastMousePosition = nil
        }
    }
}
