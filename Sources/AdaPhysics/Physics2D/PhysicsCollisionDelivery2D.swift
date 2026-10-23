import AdaECS

/// Values only: native buffers and userData are never consulted during subscriber delivery.
enum CollisionNotice2D {
    case began(CollisionEvents.Began)
    case ended(CollisionEvents.Ended)
    case hit(CollisionEvents.Hit)

    @MainActor
    func deliver(in world: PhysicsWorld2D) {
        switch self {
        case let .began(event): world.send(event)
        case let .ended(event): world.send(event)
        case let .hit(event): world.send(event)
        }
    }
}

@MainActor
extension PhysicsWorld2D {
    func processContacts() {
        guard contactsDeliveredStep != simulationStep else {
            return
        }
        prepareCollisionEvents()
        contactsDeliveredStep = simulationStep
        for notice in contactNotices { notice.deliver(in: self) }
        contactNotices.removeAll(keepingCapacity: true)
    }

    func processSensors() {
        guard sensorsDeliveredStep != simulationStep else {
            return
        }
        prepareCollisionEvents()
        sensorsDeliveredStep = simulationStep
        for notice in sensorNotices { notice.deliver(in: self) }
        sensorNotices.removeAll(keepingCapacity: true)
    }
}
