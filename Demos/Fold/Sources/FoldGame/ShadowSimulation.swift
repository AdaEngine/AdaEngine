import AdaRender
import Math

/// Deterministic kinematic simulation; rendering consumes its geometry without generating separate colliders.
public struct ShadowSimulation: Sendable {
    public let level: ShadowLevelDefinition
    public private(set) var pose = FoldPose()
    public private(set) var player: Vector2
    public private(set) var velocity = Vector2.zero
    public private(set) var polygons: [ShadowPolygon] = []
    public private(set) var checkpoint = 0
    public private(set) var completed = false
    public private(set) var plate = FoldAttachment(surface: .outer, position: Vector3(110, 220, 40))
    public private(set) var transferred = false
    public private(set) var message = ""
    public private(set) var transferFlash: Float = 0
    public private(set) var grounded = false
    public var playerSurface: FoldSurface { player.x < 400 ? .innerLeft : .innerRight }
    public var canInspectOuter: Bool { grounded && supports.contains { $0.id.hasPrefix("solid.") && $0.id == supportID } }

    private var supports: [ShadowSupport] = []
    private var supportID: String?
    private var previousInput = ShadowPlayerInput()
    private var jumpBuffer: Float = 0
    private var coyote: Float = 0
    private var accumulator: Float = 0
    private var checkpointPose = FoldPose()
    private var checkpointPlate = FoldAttachment(surface: .outer, position: Vector3(110, 220, 40))
    private var checkpointTransferred = false
    private var elapsed: Float = 0
    private var messageExpiry: Float = 0

    public init(level: ShadowLevelDefinition, pose: FoldPose = FoldPose(),
                plate: FoldAttachment = FoldAttachment(surface: .outer, position: Vector3(110, 220, 40))) {
        self.level = level
        self.player = level.start
        self.pose = pose
        self.plate = plate
        self.transferred = plate.surface != .outer
        self.checkpointPose = pose
        self.checkpointPlate = plate
        self.checkpointTransferred = plate.surface != .outer
        rebuildShadows()
    }

    public mutating func moveOuterItem(to point: Vector2) {
        guard pose.showsOuter, !transferred else { return }
        plate.position.x = min(350, max(50, point.x))
        plate.position.y = min(420, max(70, point.y))
    }

    public mutating func advance(input: ShadowPlayerInput, angle: Float, deltaTime: Float) {
        guard deltaTime.isFinite else { return }
        let dt = min(0.05, max(0, deltaTime))
        elapsed += dt
        if elapsed > messageExpiry { message = "" }
        transferFlash = max(0, transferFlash - dt)
        let oldSupports = supports
        pose.angle = FoldPose(angle: angle).playableAngle
        if input.restart != previousInput.restart { restoreCheckpoint() }
        if input.flip != previousInput.flip {
            if pose.showsOuter || canInspectOuter {
                pose.showsOuter.toggle()
                velocity = .zero
                jumpBuffer = 0
                notify(pose.showsOuter ? "Move the prism into the portal, then transfer." : "")
            } else { notify("Reach a permanent platform before turning the device.") }
        }
        if input.transfer != previousInput.transfer { transferItem() }
        if input.jump != previousInput.jump, !pose.showsOuter { jumpBuffer = 0.12 }
        previousInput = input
        rebuildShadows()
        if !pose.showsOuter, grounded, let id = supportID,
           let old = oldSupports.first(where: { $0.id == id }),
           let next = supports.first(where: { $0.id == id }),
           old.height(at: player.x) != nil, old.a != next.a || old.b != next.b {
            let fraction = (player.x - old.a.x) / max(0.001, old.b.x - old.a.x)
            let targetX = next.a.x + fraction * (next.b.x - next.a.x)
            let target = Vector2(targetX, next.height(at: targetX) ?? player.y)
            let start = player
            let distance = max(abs(target.x - start.x), abs(target.y - start.y))
            let steps = max(1, Int((distance / 4).rounded(.up)))
            for step in 1...steps {
                let candidate = start + (target - start) * (Float(step) / Float(steps))
                if hitsSolid(at: candidate, excludingTop: id) { grounded = false; supportID = nil; break }
                player = candidate
            }
        }

        guard !pose.showsOuter, !completed else { return }
        accumulator += dt
        while accumulator >= 1 / 120 {
            step(axis: input.moveX.isFinite ? min(1, max(-1, input.moveX)) : 0, dt: 1 / 120)
            accumulator -= 1 / 120
        }
    }

    private mutating func rebuildShadows() {
        polygons = level.bridges.filter { $0.minimumCheckpoint <= checkpoint && (!$0.requiresTransferredItem || transferred) }.flatMap {
            ShadowProjection.polygons(bridge: $0, pose: pose, caster: $0.requiresTransferredItem ? plate : nil)
        }
        supports = level.platforms.map { solid in
            ShadowSupport(id: "solid." + solid.id, a: Vector2(solid.rect.minX, solid.rect.maxY), b: Vector2(solid.rect.maxX, solid.rect.maxY))
        } + polygons.compactMap(\.top)
    }

    private mutating func step(axis: Float, dt: Float) {
        jumpBuffer = max(0, jumpBuffer - dt)
        coyote = grounded ? 0.1 : max(0, coyote - dt)
        if jumpBuffer > 0, coyote > 0 {
            velocity.y = 190
            jumpBuffer = 0; coyote = 0; grounded = false; supportID = nil
        }
        velocity.x = axis * 95
        let old = player
        var next = Vector2(min(792, max(8, old.x + velocity.x * dt)), old.y)
        for solid in level.platforms where supportID != "solid." + solid.id {
            let r = solid.rect
            guard old.y < r.maxY - 0.5, old.y + 30 > r.minY else { continue }
            if velocity.x > 0, old.x <= r.minX, next.x + 9 > r.minX { next.x = min(old.x, r.minX - 9) }
            if velocity.x < 0, old.x >= r.maxX, next.x - 9 < r.maxX { next.x = max(old.x, r.maxX + 9) }
        }
        if grounded, let id = supportID, let support = supports.first(where: { $0.id == id }),
           let y = support.height(at: next.x), abs(y - old.y) < 12 {
            next.y = y
            velocity.y = 0
        } else {
            grounded = false; supportID = nil
            velocity.y -= 800 * dt
            next.y = old.y + velocity.y * dt
            if velocity.y <= 0 {
                let landings = supports.compactMap { support -> (ShadowSupport, Float)? in
                    guard let y = support.height(at: next.x), old.y >= y - 0.5, next.y <= y else { return nil }
                    return (support, y)
                }
                if let landing = landings.max(by: { $0.1 < $1.1 }) {
                    next.y = landing.1; velocity.y = 0; grounded = true; supportID = landing.0.id
                }
            } else if hitsSolid(at: next, excludingTop: nil) { next.y = old.y; velocity.y = 0 }
        }
        player = next
        if player.y < -60 { restoreCheckpoint(); notify("Try a different fold. Your checkpoint is safe.") }
        if grounded, checkpoint < level.checkpoints.count {
            let target = level.checkpoints[checkpoint]
            if abs(player.x - target.x) < 20, abs(player.y - target.y) < 12 {
                checkpoint += 1
                checkpointPose = pose; checkpointPlate = plate; checkpointTransferred = transferred
                notify("Checkpoint reached")
            }
        }
        if player.x >= level.exitX, grounded { completed = true; notify("You folded the light. You found the way.") }
    }

    private func hitsSolid(at feet: Vector2, excludingTop: String?) -> Bool {
        level.platforms.contains { solid in
            if excludingTop == "solid." + solid.id { return false }
            let r = solid.rect
            return feet.x + 9 > r.minX && feet.x - 9 < r.maxX && feet.y + 30 > r.minY + 0.1 && feet.y < r.maxY - 0.5
        }
    }

    private mutating func transferItem() {
        guard pose.showsOuter else { notify("Turn to the outer screen to transfer a prism."); return }
        guard !transferred else { notify("The prism is already inside."); return }
        let delta = Vector2(plate.position.x, plate.position.y) - level.portal
        guard delta.x * delta.x + delta.y * delta.y < 55 * 55 else { notify("Drag the prism onto the glowing portal."); return }
        let destination = level.transferDestination
        let flat = Vector2(destination.x + 400, destination.y)
        guard !hitsSolid(at: flat, excludingTop: nil), abs(flat.x - player.x) > 25 || abs(flat.y - player.y) > 35 else {
            notify("The destination is occupied."); return
        }
        plate = FoldAttachment(surface: .innerRight, position: destination)
        transferred = true; transferFlash = 1
        notify("Prism transferred. Turn inside to shape its shadow.")
    }

    private mutating func notify(_ text: String) { message = text; messageExpiry = elapsed + 2 }

    private mutating func restoreCheckpoint() {
        player = checkpoint == 0 ? level.start : level.checkpoints[checkpoint - 1]
        pose = checkpointPose; pose.showsOuter = false
        plate = checkpointPlate; transferred = checkpointTransferred
        velocity = .zero; grounded = false; supportID = nil; completed = false
        jumpBuffer = 0; coyote = 0; accumulator = 0
        rebuildShadows()
    }
}
