import AdaEngine
import AdaNavigationBaking
import Foundation

/// The same geometry drives the bake, physical colliders, and visible meshes.
@MainActor
enum NavigationDemoFixture {
    struct Obstacle {
        let center: Vector3
        let size: Vector3
    }

    static let start = Vector3(-8, 0, -4)
    static let goals: [Vector3] = [[8, 0, 4], [-8, 0, 5], [8, 0, -5], [0, 0, 5]]
    static let obstacles = [
        Obstacle(center: [0, 1.5, 0], size: [4, 3, 4]),
        Obstacle(center: [-5.5, 1.1, 0], size: [1.4, 2.2, 6]),
        Obstacle(center: [5, 1.1, 2.5], size: [2, 2.2, 3])
    ]

    static func bakedAsset() async throws -> NavigationMeshData {
        var vertices: [Vector3] = [[-10, 0, -7], [-10, 0, 7], [10, 0, 7], [10, 0, -7]]
        var indices: [UInt32] = [0, 1, 2, 0, 2, 3]
        for box in obstacles {
            let min = box.center - box.size / 2
            let max = box.center + box.size / 2
            let corners: [Vector3] = [
                [min.x, min.y, min.z], [min.x, min.y, max.z], [max.x, min.y, max.z], [max.x, min.y, min.z],
                [min.x, max.y, min.z], [min.x, max.y, max.z], [max.x, max.y, max.z], [max.x, max.y, min.z]
            ]
            let offset = UInt32(vertices.count)
            vertices += corners
            // Outward winding: ceiling on the bottom, walkable top, and blocking walls.
            indices += [0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
                        0, 1, 5, 0, 5, 4, 3, 7, 6, 3, 6, 2,
                        0, 4, 7, 0, 7, 3, 1, 2, 6, 1, 6, 5].map { offset + $0 }
        }
        let baked = try await NavigationMeshBaker.bake(vertices: vertices, indices: indices)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AdaEngine-NavigationDemo", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("playground.navmesh")
        try baked.encoded().write(to: url, options: .atomic)
        // Exercise the production file decoder before installing the map.
        return try NavigationMeshData(encoded: Data(contentsOf: url))
    }

    @discardableResult
    static func installPhysics(in world: World) -> Entity {
        func box(_ name: String, center: Vector3, size: Vector3) {
            world.spawn(name) {
                Transform(position: center)
                PhysicsBody3DComponent(shapes: [.generateBox(width: size.x, height: size.y, depth: size.z)], mode: .static)
            }
        }
        box("Floor", center: [0, -0.3, 0], size: [20, 0.6, 14])
        for (index, obstacle) in obstacles.enumerated() { box("Obstacle \(index)", center: obstacle.center, size: obstacle.size) }
        return world.spawn("Navigation robot") {
            Transform(position: start)
            CharacterController3DComponent()
            NavigationAgent3DComponent()
            NavigationTarget3DComponent(destination: goals[0])
        }
    }

    static func installGraphics(in world: World, robot: Entity) {
        let device = unsafe RenderEngine.shared.renderDevice
        func material(_ color: Vector4) -> PBRMaterial {
            let result = PBRMaterial()
            result.baseColorFactor = color
            result.metallicFactor = 0
            result.roughnessFactor = 0.75
            return result
        }
        let cube = Mesh.generateCube(renderDevice: device)
        for entity in world.getEntities() where entity.components[PhysicsBody3DComponent.self] != nil {
            let size = entity.name == "Floor" ? Vector3(20, 0.6, 14)
                : obstacles[Int(entity.name.split(separator: " ").last ?? "0") ?? 0].size
            var transform = entity.components[Transform.self] ?? Transform()
            transform.scale = size
            entity.components[Transform.self] = transform
            entity.components[Mesh3DComponent.self] = Mesh3DComponent(
                mesh: cube, materials: [material(entity.name == "Floor" ? [0.18, 0.24, 0.31, 1] : [0.55, 0.48, 0.8, 1])]
            )
        }
        let sphere = Mesh.generateSphere(radius: 1, segments: 24, rings: 16, renderDevice: device)
        func part(_ name: String, at position: Vector3, scale: Vector3, color: Vector4) {
            let entity = world.spawn(name) {
                Transform(scale: scale, position: position)
                Mesh3DComponent(mesh: sphere, materials: [material(color)])
            }
            robot.addChild(entity)
        }
        part("Body", at: [0, 0.7, 0], scale: [0.36, 0.55, 0.32], color: [0.05, 0.8, 0.85, 1])
        part("Head", at: [0, 1.5, 0], scale: [0.32, 0.32, 0.32], color: [1, 0.8, 0.2, 1])
        for x: Float in [-0.12, 0.12] {
            part("Eye", at: [x, 1.55, -0.28], scale: [0.055, 0.075, 0.045], color: [0.03, 0.05, 0.1, 1])
        }
        var camera = Camera()
        camera.backgroundColor = Color(0.035, 0.055, 0.09, 1)
        let eye = Vector3(12, 16, -18)
        let forward = (-eye).normalized
        let right = Vector3.up.cross(forward).normalized
        let up = forward.cross(right)
        let cameraMatrix = Transform3D(columns: [Vector4(right, 0), Vector4(up, 0), Vector4(forward, 0), Vector4(eye, 1)])
        world.spawn("Playground camera", bundle: Camera3D(
            camera: camera,
            perspectiveProjection: PerspectiveProjection(fieldOfView: .degrees(45)),
            transform: Transform(matrix: cameraMatrix)
        ))
        world.spawn("Sun") {
            Transform(rotation: Quat(axis: .right, angle: .pi / 3))
            DirectionalLightComponent(intensity: 3, castShadows: true)
        }
    }
}
