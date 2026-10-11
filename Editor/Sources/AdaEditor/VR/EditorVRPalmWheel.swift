@_spi(Internal) import AdaEngine

@MainActor
final class EditorVRPalmWheel {
    static let panels: [EditorVRPanel] = [.files, .code, .assets, .console, .agent, .settings]
    private var sectors: [Entity.ID: EditorVRPanel] = [:]
    private var closeID: Entity.ID?
    private var closeLabelID: Entity.ID?
    private var labels: [Entity.ID] = []
    private var suppressed = false
    private var open = false
    private var previousSelection: Entity.ID?

    var isVisible: Bool { open }

    /// The renderer releases the old world when immersion ends; IDs must not escape that world.
    func reset() {
        sectors.removeAll()
        labels.removeAll()
        closeID = nil
        closeLabelID = nil
        previousSelection = nil
        suppressed = false
        open = false
    }

    func update(in world: World, tracking: SpatialTrackingFrame, activate: (EditorVRPanel) -> Void) {
        if world.getResource(SpatialSelection.self)?.isGrabbed == true {
            setVisible(false, in: world)
            return
        }
        let hand = tracking.hands.first { Self.shouldPresent(hand: $0, head: tracking.head) }
        guard let hand else {
            suppressed = false
            setVisible(false, in: world)
            return
        }
        if open, world.getResource(SpatialSelection.self)?.entityID == closeID, closeID != nil {
            world.insertResource(SpatialSelection(entityID: previousSelection))
            suppressed = true
            setVisible(false, in: world)
            return
        }
        if let selection = world.getResource(SpatialSelection.self), let id = selection.entityID, let panel = sectors[id], open {
            activate(panel)
            world.insertResource(SpatialSelection(entityID: previousSelection))
            suppressed = true
            setVisible(false, in: world)
            return
        }
        guard !suppressed, let device = unsafe RenderEngine.shared?.renderDevice else {
            return
        }
        if sectors.isEmpty { build(in: world, device: device) }
        if !open { previousSelection = world.getResource(SpatialSelection.self)?.entityID }
        setVisible(true, in: world)
        let head = tracking.head
        let center = hand.pose.origin + (head.origin - hand.pose.origin).normalized * 0.06
        let matrix = Transform(rotation: head.rotation, position: center).matrix
        if let closeID { world.getEntityByID(closeID)?.components[Transform.self] = Transform(matrix: matrix) }
        if let closeLabelID {
            world.getEntityByID(closeLabelID)?.components[Transform.self] = Transform(
                rotation: head.rotation,
                scale: [0.03, 0.03, 1],
                position: (matrix * Vector4(0, 0, -0.004, 1)).xyz
            )
        }
        for id in sectors.keys {
            world.getEntityByID(id)?.components[Transform.self] = Transform(matrix: matrix)
        }
        let radius: Float = 0.085
        for (index, id) in labels.enumerated() {
            let angle = (Float(index) + 0.5) / 6 * .pi * 2
            let local = Vector3(Math.cos(angle) * radius, Math.sin(angle) * radius - 0.009, -0.003)
            #if os(visionOS)
                world.getEntityByID(id)?.components[Transform.self] = Transform(
                    rotation: head.rotation,
                    scale: [0.065, 0.018, 1],
                    position: (matrix * Vector4(local, 1)).xyz
                )
            #else
                world.getEntityByID(id)?.components[Transform.self] = Transform(
                    rotation: head.rotation,
                    scale: Vector3(0.0008),
                    position: (matrix * Vector4(local, 1)).xyz
                )
            #endif
        }
    }

    static func shouldPresent(hand: SpatialHandPose, head: Transform3D) -> Bool {
        guard hand.isOpen else {
            return false
        }
        let offset = hand.pose.origin - head.origin
        let distance = offset.length
        guard distance > 0.18, distance < 0.8 else {
            return false
        }
        let forward = (head * Vector4(0, 0, 1, 0)).xyz.normalized
        return forward.dot(offset.normalized) > 0.72 && abs(hand.palmNormal.dot(-offset.normalized)) > 0.4
    }

    private func setVisible(_ visible: Bool, in world: World) {
        open = visible
        for id in Array(sectors.keys) + labels + [closeID, closeLabelID].compactMap({ $0 }) {
            world.getEntityByID(id)?.isActive = visible
            world.getEntityByID(id)?.components[Visibility.self] = visible ? .visible : .hidden
        }
    }

    private func build(in world: World, device: RenderDevice) {
        closeID =
            world.spawn("Palm Close") {
                Transform()
                Mesh3DComponent(
                    mesh: Mesh.generateCircle(radius: 0.035, renderDevice: device),
                    materials: [EditorVRGizmoController.material([0.05, 0.07, 0.11])],
                    castShadows: false,
                    receiveShadows: false
                )
                SpatialGrabbable(halfExtents: [0.04, 0.04, 0.01], shape: .ring(axis: 2, innerRadius: 0, outerRadius: 0.035), allowsManipulation: false)
                Visibility.hidden
            }.id
        #if os(visionOS)
            closeLabelID = EditorVRPalmLabel.make("×", in: world, device: device)?.id
        #endif
        let names = ["Project", "Code", "Assets", "Console", "Agent", "Settings"]
        for index in 0..<6 {
            let start = Float(index) / 6 * .pi * 2 + 0.025
            let end = Float(index + 1) / 6 * .pi * 2 - 0.025
            var descriptor = MeshDescriptor(name: "Palm Sector \(index)")
            var vertices: [Vector3] = []
            var indices: [UInt32] = []
            for step in 0...16 {
                let angle = start + (end - start) * Float(step) / 16
                vertices.append([Math.cos(angle) * 0.04, Math.sin(angle) * 0.04, 0])
                vertices.append([Math.cos(angle) * 0.13, Math.sin(angle) * 0.13, 0])
                if step < 16 {
                    let base = UInt32(step * 2)
                    indices += [base, base + 1, base + 2, base + 2, base + 1, base + 3]
                }
            }
            descriptor.positions = MeshBuffer(vertices)
            descriptor.normals = MeshBuffer(Array(repeating: Vector3(0, 0, -1), count: vertices.count))
            descriptor.indicies = indices
            let mesh = Mesh.generate(from: [descriptor], renderDevice: device)
            let material = EditorVRGizmoController.material([0.08, 0.12, 0.19])
            let entity = world.spawn("Palm \(names[index])") {
                Transform()
                Mesh3DComponent(mesh: mesh, materials: [material], castShadows: false, receiveShadows: false)
                SpatialGrabbable(
                    halfExtents: [0.21, 0.21, 0.02],
                    shape: .ring(axis: 2, innerRadius: 0.04, outerRadius: 0.13, startAngle: start, endAngle: end),
                    allowsManipulation: false
                )
                Visibility.hidden
            }
            sectors[entity.id] = Self.panels[index]
            var text = AttributedText(names[index])
            text.font = .system(size: 22)
            text.foregroundColor = .white
            #if os(visionOS)
                if let label = EditorVRPalmLabel.make(names[index], in: world, device: device) { labels.append(label.id) }
            #else
                labels.append(world.spawn("Palm Label \(index)", bundle: Text2D(textComponent: TextComponent(text: text))).id)
            #endif
        }
    }
}
