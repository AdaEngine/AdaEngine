import AdaEngine
import AdaUtils
@_spi(Internal) import AdaInput
@_spi(Internal) import AdaRender
import Math

@main
struct LargePyramidBenchmarkExample: App {
    var body: some AppScene {
        GameAppScene {
            let world = World()
            return Scene(from: world)
        }
        .addPlugins(DefaultPlugins()
            .disable(AudioPlugin.self)
            .disable(SpritePlugin.self)
            .disable(Mesh2DPlugin.self)
            .disable(TextPlugin.self)
            .disable(Core2DPlugin.self)
            .disable(Light2DPlugin.self)
            .disable(UIPlugin.self)
            .disable(ContextMenuPlugin.self)
            .disable(Physics2DPlugin.self)
            .disable(TileMapPlugin.self)
            .set(LargePyramidPhysicsConfigurationPlugin())
            .set(Physics3DPlugin(subStepCount: 1))
            .set(LargePyramidBenchmarkPlugin())
        )
        .windowMode(.windowed)
    }

    fileprivate static let pyramidRows = 180
    fileprivate static let boxSize = Vector3(0.45, 0.45, 0.45)
    fileprivate static let boxSpacing: Float = 0.5

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

private struct LargePyramidPhysicsConfigurationPlugin: Plugin {
    func setup(in app: AppWorlds) {
        app.insertResource(
            PhysicsSimulationThreading(
                workerCount: 8,
                box3DWorkerCount: 8
            )
        )
    }
}

private struct LargePyramidBenchmarkPlugin: Plugin {
    func setup(in app: AppWorlds) {
        app.addSystem(LargePyramidBenchmarkSetupSystem.self, on: .startup)
    }
}

@System
@MainActor
func LargePyramidBenchmarkSetup(_ commands: Commands) {
    let cameraTransform = Transform(
        rotation: Quat.euler([0.08, 0, 0]),
        position: [0, 38, -92]
    )

    commands.spawn("Camera", bundle:
        PerspectiveCameraBundle(
            camera: Camera(window: .primary),
            transform: cameraTransform
        )
    )
    .insert(ScriptableComponents(scripts: [LargePyramidBenchmarkCamera()]))

    let floorMaterial = LargePyramidBenchmarkExample.makeMaterial(color: [0.62, 0.63, 0.67, 1])
    let floorMesh = LargePyramidBenchmarkExample.makeBoxMesh(
        name: "Benchmark Floor",
        size: [160, 1, 40]
    )
    commands.spawn("Floor") {
        Mesh3DComponent(mesh: floorMesh, materials: [floorMaterial])
        PhysicsBody3DComponent(
            shapes: [Shape3DResource.generateBox(width: 160, height: 1, depth: 40)],
            mode: .static
        )
        Transform(position: [0, -0.5, 0])
    }

    let cubeMesh = LargePyramidBenchmarkExample.makeBoxMesh(
        name: "Benchmark Pyramid Cube",
        size: LargePyramidBenchmarkExample.boxSize
    )
    let cubeMaterial = LargePyramidBenchmarkExample.makeMaterial(color: [0.84, 0.76, 0.65, 1])
    let boxShape = Shape3DResource.generateBox(
        width: LargePyramidBenchmarkExample.boxSize.x,
        height: LargePyramidBenchmarkExample.boxSize.y,
        depth: LargePyramidBenchmarkExample.boxSize.z
    )

    let halfHeight = LargePyramidBenchmarkExample.boxSize.y / 2
    let rows = LargePyramidBenchmarkExample.pyramidRows
    let spacing = LargePyramidBenchmarkExample.boxSpacing

    for row in 0..<rows {
        let count = rows - row
        let y = halfHeight + Float(row) * spacing
        let rowWidth = Float(count - 1) * spacing
        let startX = -rowWidth / 2

        for column in 0..<count {
            let x = startX + Float(column) * spacing
            commands.spawn("Pyramid Box \(row)-\(column)") {
                Mesh3DComponent(mesh: cubeMesh, materials: [cubeMaterial])
                PhysicsBody3DComponent(
                    shapes: [boxShape],
                    mass: 1,
                    material: PhysicsMaterial.generate(friction: 0.7, restitution: 0.02, density: 1),
                    mode: .dynamic
                )
                Transform(position: [x, y, 0])
            }
        }
    }
}

final class LargePyramidBenchmarkCamera: ScriptableObject, @unchecked Sendable {

    @RequiredComponent var cameraTransform: Transform
    @RequiredComponent var camera: Camera

    var speed: Float = 18.0
    var sensitivity: Float = 5.0

    private var lastMousePosition: Vector2?
    private var rotation: Vector3 = [0.08, 0, 0]
    private var shootCooldown = FixedTimestep(stepsPerSecond: 5)

    @MainActor
    private var projectileMesh = LargePyramidBenchmarkExample.makeSphereMesh(
        name: "Benchmark Projectile",
        radius: 0.75,
        segments: 18,
        rings: 10
    )

    @MainActor
    private var projectileMaterial = LargePyramidBenchmarkExample.makeMaterial(color: [0.68, 0.92, 0.18, 1])

    private var cameraRotation: Quat {
        let pitch = Transform3D.identity.rotate(angle: .radians(rotation.x), axis: .right)
        let yaw = Transform3D.identity.rotate(angle: .radians(rotation.y), axis: .up)
        return Quat(rotationMatrix: yaw * pitch)
    }

    override func ready() {
        cameraTransform.rotation = cameraRotation
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

        if input.mouseEvents[.left]?.phase == .began,
           shootCooldown.advance(with: deltaTime).isFixedTick {
            shootProjectile()
        }

        if let phase = input.mouseEvents[.right]?.phase {
            switch phase {
            case .began:
                lastMousePosition = input.getMousePosition()
            case .changed:
                let currentMousePosition = input.getMousePosition()
                if let lastMousePosition {
                    let delta = currentMousePosition - lastMousePosition
                    rotation.y += delta.x * sensitivity * dt
                    rotation.x += delta.y * sensitivity * dt
                    rotation.x = clamp(rotation.x, -1.5, 1.5)
                    cameraTransform.rotation = cameraRotation
                }
                self.lastMousePosition = currentMousePosition
            default:
                lastMousePosition = nil
            }
        } else {
            lastMousePosition = nil
        }
    }

    private func shootProjectile() {
        guard
            let entity,
            let world,
            let cameraGlobalTransform = entity.components[GlobalTransform.self],
            let ray = camera.viewportToWorld(
                cameraGlobalTransform: cameraGlobalTransform.matrix,
                point: input.getMousePosition()
            )
        else {
            return
        }

        Task { @MainActor in
            let spawnPosition = ray.point(in: 4.0)
            world.spawn("Projectile") {
                Mesh3DComponent(mesh: projectileMesh, materials: [projectileMaterial])
                PhysicsBody3DComponent(
                    shapes: [Shape3DResource.generateSphere(radius: 0.75)],
                    mass: 40,
                    material: PhysicsMaterial.generate(friction: 0.35, restitution: 0.12, density: 1.5),
                    mode: .dynamic
                )
                Transform(position: spawnPosition)
                NoFrustumCulling()
                ScriptableComponents(scripts: [ProjectileLaunchScript(initialVelocity: ray.direction * 95)])
            }
        }
    }
}

final class ProjectileLaunchScript: ScriptableObject, @unchecked Sendable {
    private var initialVelocity: Vector3 = .zero
    private var remainingLaunchFrames = 8

    required init() {
        super.init()
    }

    init(initialVelocity: Vector3) {
        self.initialVelocity = initialVelocity
        super.init()
    }

    required init(from decoder: any Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    override func update(_ deltaTime: AdaUtils.TimeInterval) {
        guard remainingLaunchFrames > 0, var physicsBody = entity?.components[PhysicsBody3DComponent.self] else {
            return
        }

        physicsBody.linearVelocity = initialVelocity
        entity?.components += physicsBody
        remainingLaunchFrames -= 1
    }
}
