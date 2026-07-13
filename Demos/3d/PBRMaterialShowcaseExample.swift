import AdaEngine
@_spi(Internal) import AdaInput
@_spi(Internal) import AdaRender
import AdaUtils
import Math

@main
struct PBRMaterialShowcaseExample: App {
    fileprivate static let columnCount = 7
    fileprivate static let rowCount = 5
    fileprivate static let spacing: Float = 1.45

    var body: some AppScene {
        GameAppScene {
            Scene(from: World())
        }
        .addPlugins(DefaultPlugins().set(PBRMaterialShowcasePlugin()))
        .windowMode(.windowed)
    }

    fileprivate static func makeSphereMesh(radius: Float, segments: Int, rings: Int) -> Mesh {
        var descriptor = MeshDescriptor(name: "PBR Showcase Sphere")
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
                let normal = Vector3(
                    x: ringRadius * Math.cos(phi),
                    y: y,
                    z: ringRadius * Math.sin(phi)
                )
                positions.append(normal * radius)
                normals.append(normal)
            }
        }

        let stride = segments + 1
        for ring in 0..<rings {
            for segment in 0..<segments {
                let current = UInt32(ring * stride + segment)
                let next = UInt32((ring + 1) * stride + segment)
                indices.append(contentsOf: [
                    current, next, current + 1,
                    current + 1, next, next + 1
                ])
            }
        }

        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.indicies = indices
        return Mesh.generate(from: [descriptor], renderDevice: unsafe RenderEngine.shared.renderDevice)
    }

    fileprivate static func makeFloorMesh() -> Mesh {
        var descriptor = MeshDescriptor(name: "PBR Showcase Floor")
        descriptor.positions = MeshBuffer<Vector3>([
            [-7, 0, -3],
            [7, 0, -3],
            [7, 0, 7],
            [-7, 0, 7]
        ])
        descriptor.normals = MeshBuffer<Vector3>(Array(repeating: .up, count: 4))
        descriptor.indicies = [0, 2, 1, 0, 3, 2]
        return Mesh.generate(from: [descriptor], renderDevice: unsafe RenderEngine.shared.renderDevice)
    }
}

private struct PBRMaterialShowcasePlugin: Plugin {
    func setup(in app: AppWorlds) {
        app.addSystem(PBRMaterialShowcaseSetupSystem.self, on: .startup)
    }
}

@System
@MainActor
func PBRMaterialShowcaseSetup(_ commands: Commands) {
    commands.spawn(
        "Camera",
        bundle: PerspectiveCameraBundle(
            camera: Camera(window: .primary),
            transform: Transform(position: [0, 0.4, -14.5])
        )
    )
    .insert(
        Environment3D(
            skybox: Skybox3D(
                zenithColor: Color(red: 0.08, green: 0.18, blue: 0.38),
                horizonColor: Color(red: 0.68, green: 0.72, blue: 0.78),
                groundColor: Color(red: 0.04, green: 0.045, blue: 0.055),
                intensity: 1.25
            ),
            screenSpaceReflection: ScreenSpaceReflection(
                maxDistance: 24,
                stride: 0.18,
                thickness: 0.16,
                maxSteps: 64,
                intensity: 0.85
            )
        )
    )
    .insert(ScriptableComponents(scripts: [PBRShowcaseFreeCamera()]))

    commands.spawn("Key Light") {
        DirectionalLightComponent(
            radiance: [1, 0.92, 0.82],
            intensity: 4.2,
            castShadows: true,
            shadowDistance: 30,
            shadowBias: 0.0008,
            shadowSlopeBias: 0.003
        )
        Transform(rotation: Quat.euler([-0.55, 0.65, 0]))
    }

    let sphere = PBRMaterialShowcaseExample.makeSphereMesh(radius: 0.52, segments: 32, rings: 20)
    for row in 0..<PBRMaterialShowcaseExample.rowCount {
        let metallic = Float(row) / Float(PBRMaterialShowcaseExample.rowCount - 1)
        for column in 0..<PBRMaterialShowcaseExample.columnCount {
            let roughness = max(0.04, Float(column) / Float(PBRMaterialShowcaseExample.columnCount - 1))
            let material = PBRMaterial()
            material.baseColorFactor = [0.92, 0.24, 0.08, 1]
            material.metallicFactor = metallic
            material.roughnessFactor = roughness

            let x = (Float(column) - Float(PBRMaterialShowcaseExample.columnCount - 1) / 2) * PBRMaterialShowcaseExample.spacing
            let y = (Float(PBRMaterialShowcaseExample.rowCount - 1) / 2 - Float(row)) * PBRMaterialShowcaseExample.spacing
            commands.spawn("M \(metallic), R \(roughness)") {
                Mesh3DComponent(mesh: sphere, materials: [material])
                Transform(position: [x, y, 0])
            }
        }
    }

    let floorMaterial = PBRMaterial()
    floorMaterial.baseColorFactor = [0.22, 0.24, 0.28, 1]
    floorMaterial.metallicFactor = 0.15
    floorMaterial.roughnessFactor = 0.22
    let floorMesh = PBRMaterialShowcaseExample.makeFloorMesh()
    commands.spawn("Reflective Floor") {
        Mesh3DComponent(mesh: floorMesh, materials: [floorMaterial])
        Transform(position: [0, -3.75, 1.5])
    }
}

/// Free-fly controls for inspecting the PBR grid and its shadows.
final class PBRShowcaseFreeCamera: ScriptableObject, @unchecked Sendable {
    @RequiredComponent private var cameraTransform: Transform

    private let movementSpeed: Float = 5
    private let sprintMultiplier: Float = 3
    private let mouseSensitivity: Float = 0.004
    private var lastMousePosition: Vector2?
    private var rotation: Vector2 = .zero

    private var cameraRotation: Quat {
        let pitch = Transform3D.identity.rotate(angle: .radians(rotation.x), axis: .right)
        let yaw = Transform3D.identity.rotate(angle: .radians(rotation.y), axis: .up)
        return Quat(rotationMatrix: yaw * pitch)
    }

    override func update(_ deltaTime: AdaUtils.TimeInterval) {
        updateMovement(deltaTime: deltaTime)
        updateRotation()
    }

    private func updateMovement(deltaTime: AdaUtils.TimeInterval) {
        var direction = Vector3.zero
        if input.isKeyPressed(.w) { direction.z += 1 }
        if input.isKeyPressed(.s) { direction.z -= 1 }
        if input.isKeyPressed(.a) { direction.x -= 1 }
        if input.isKeyPressed(.d) { direction.x += 1 }
        if input.isKeyPressed(.e) { direction.y += 1 }
        if input.isKeyPressed(.q) { direction.y -= 1 }

        guard direction != .zero else {
            return
        }

        let localDirection = Transform3D(quat: cameraRotation) * Vector4(direction.normalized, 0)
        let speed = movementSpeed * (input.isKeyPressed(.shift) ? sprintMultiplier : 1)
        cameraTransform.position += localDirection.xyz * (speed * Float(deltaTime))
    }

    private func updateRotation() {
        guard input.isMouseButtonPressed(.left) else {
            lastMousePosition = nil
            return
        }

        let mousePosition = input.getMousePosition()
        if let lastMousePosition {
            let delta = mousePosition - lastMousePosition
            rotation.y -= delta.x * mouseSensitivity
            rotation.x = clamp(
                rotation.x - delta.y * mouseSensitivity,
                -.pi / 2 + 0.01,
                .pi / 2 - 0.01
            )
            cameraTransform.rotation = cameraRotation
        }
        lastMousePosition = mousePosition
    }
}
