import AdaECS
import AdaTransform
import Math

/// Retains motion state when only the nearby Float coordinate frame changes.
@PlainSystem(dependencies: [.after(PhysicsCoordinate2DSyncSystem.self), .before(DynamicCharacter2DSyncSystem.self)])
struct CharacterCoordinate2DSyncSystem {
    @Query<Ref<CharacterController2DComponent>> private var characters
    @Res<Physics2DWorldHolder> private var physics
    init(world _: World) {}

    @MainActor
    func update(context _: UpdateContext) {
        let origin = physics.world.coordinateOrigin
        characters.forEach { controller in
            controller.wrappedValue.rebaseCoordinates(to: origin)
        }
    }
}

@MainActor
extension CharacterController2DComponent {
    mutating func rebaseCoordinates(to origin: PhysicsPosition2D) {
        defer { lastCoordinateOrigin = origin }
        guard let previous = lastCoordinateOrigin, previous != origin else {
            return
        }
        if let lastPosition { self.lastPosition = (lastGlobalPosition ?? previous.offset(by: lastPosition)).displacement(from: origin) }
        if let groundPoint { self.groundPoint = previous.offset(by: groundPoint).displacement(from: origin) }
        runtime?.planes.removeAll(keepingCapacity: true)
        runtime?.contacts.removeAll(keepingCapacity: true)
    }
}
