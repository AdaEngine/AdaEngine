import AdaEngine
@_spi(Internal) import AdaRender

/// Native lights and shadow casters share the game's projected screen geometry.
/// The analytic shadow platforms still own collision; physical objects cast real Light2D shadows on the paper.
@MainActor
final class FoldLightingScene {
    private var entities: [String: Entity] = [:]
    private var lastSize = Size.zero
    private var lastPose: FoldPose?

    func update(world: World, game: ShadowSimulation, size: Size) {
        guard size.width > 0, size.height > 0,
              let device = world.getResource(RenderDeviceHandler.self)?.renderDevice else { return }
        let map = ShadowScreenMapping(size: size, pose: game.pose)
        for camera in world.getEntities() where camera.components[Camera.self] != nil {
            var value = camera.components[Camera.self]
            value?.backgroundColor = Color.fromHex(0x182639)
            if let value { camera.components += value }
        }
        let ambient = entity("Ambient", world: world)
        ambient.components += LightModulate2D(color: Color(red: 0.40, green: 0.43, blue: 0.49))
        let rebuildPaper = size != lastSize || game.pose != lastPose
        for (index, surface) in [FoldSurface.innerLeft, .innerRight].enumerated() {
            let paper = entity("Paper\(index)", world: world)
            paper.components[Visibility.self] = game.pose.showsOuter ? .hidden : .visible
            if rebuildPaper {
                let corners = [Vector3(0, 0, 0), Vector3(400, 0, 0), Vector3(400, 480, 0), Vector3(0, 480, 0)]
                let points = corners.map { Self.worldPoint(map.point($0, surface: surface), size: size) }
                var descriptor = MeshDescriptor(name: "Fold paper \(index)")
                descriptor.positions = MeshBuffer(points.map { Vector3($0.x, $0.y, 0) })
                descriptor.normals = MeshBuffer(Array(repeating: Vector3(0, 0, 1), count: 4))
                descriptor.textureCoordinates = MeshBuffer([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
                descriptor.indicies = [0, 1, 2, 0, 2, 3]
                let materials = paper.components[Mesh2D.self]?.materials ?? [CustomMaterial(ColorCanvasMaterial(color: .fromHex(index == 0 ? 0xEFE7D4 : 0xDDD4C2)))]
                let mesh = Mesh.generate(from: [descriptor], renderDevice: device)
                paper.components += Mesh2D(mesh: mesh, materials: materials)
                paper.components += BoundingComponent(bounds: .aabb(mesh.bounds))
                paper.components += NoFrustumCulling()
            }
        }
        lastSize = size; lastPose = game.pose

        var active: Set<String> = ["Ambient", "Paper0", "Paper1"]
        if !game.pose.showsOuter {
            for (index, bridge) in game.level.bridges.enumerated() where bridge.minimumCheckpoint == min(game.checkpoint, 2) {
                let lightID = "Light\(index)"
                let light = entity(lightID, world: world)
                let position = Self.worldPoint(map.point(bridge.lamp.position, surface: bridge.lamp.surface), size: size)
                light.components += Transform(position: Vector3(position.x, position.y, 0))
                light.components += Light2D(color: Color(red: 1, green: 0.87, blue: 0.65), energy: 1.1, radius: 850 * map.scale, castsShadows: true)
                light.components[Visibility.self] = .visible
                active.insert(lightID)
                if !bridge.requiresTransferredItem || game.transferred {
                    let attachment = bridge.requiresTransferredItem ? game.plate : bridge.caster
                    let p = attachment.position
                    let corners = [Vector3(p.x - bridge.width / 2, p.y, p.z), Vector3(p.x + bridge.width / 2, p.y, p.z),
                                   Vector3(p.x + bridge.width / 2, p.y - bridge.height, p.z), Vector3(p.x - bridge.width / 2, p.y - bridge.height, p.z)]
                    occluder("Prism\(index)", points: corners.map { map.point($0, surface: attachment.surface) }, size: size, world: world, active: &active)
                }
            }
            for solid in game.level.platforms {
                let r = solid.rect
                occluder("Solid.\(solid.id)", points: [Vector2(r.minX, r.minY), Vector2(r.maxX, r.minY), Vector2(r.maxX, r.maxY), Vector2(r.minX, r.maxY)].map(map.flat),
                         size: size, world: world, active: &active)
            }
            let p = game.player
            occluder("Traveller", points: [p + Vector2(-9, 0), p + Vector2(10, 0), p + Vector2(7, 30), p + Vector2(-6, 30)].map(map.flat),
                     size: size, world: world, active: &active)
        }
        for (id, value) in entities where !active.contains(id) { value.components[Visibility.self] = .hidden }
    }

    static func worldPoint(_ point: Vector2, size: Size) -> Vector2 {
        Vector2(point.x - size.width / 2, size.height / 2 - point.y)
    }

    private func entity(_ id: String, world: World) -> Entity {
        if let value = entities[id] { return value }
        let value = world.spawn("Fold Lighting / \(id)") { Transform(); Visibility.visible }
        entities[id] = value
        return value
    }

    private func occluder(_ id: String, points: [Vector2], size: Size, world: World, active: inout Set<String>) {
        var ring = points.map { Self.worldPoint($0, size: size) }
        let area = ring.indices.reduce(Float(0)) { sum, i in
            let a = ring[i], b = ring[(i + 1) % ring.count]
            return sum + a.x * b.y - b.x * a.y
        }
        if area < 0 { ring.reverse() }
        let value = entity(id, world: world)
        value.components += LightOccluder2D(points: ring)
        value.components[Visibility.self] = .visible
        active.insert(id)
    }
}
