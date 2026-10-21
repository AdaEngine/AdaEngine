import AdaECS
import AdaUtils
import box2d
import Math

/// Nil thresholds disable reporting. Removal is explicit engine policy; Box2D only reports events.
public struct JointBreak2DSettings: Codable, Equatable, Sendable {
    public var forceThreshold: Float?
    public var torqueThreshold: Float?
    public var removeOnBreak: Bool
    public init(forceThreshold: Float? = nil, torqueThreshold: Float? = nil, removeOnBreak: Bool = true) {
        self.forceThreshold = forceThreshold
        self.torqueThreshold = torqueThreshold
        self.removeOnBreak = removeOnBreak
    }
    func validate() throws(PhysicsJoint2DError) {
        guard forceThreshold.map({ $0.isFinite && $0 >= 0 }) != false,
            torqueThreshold.map({ $0.isFinite && $0 >= 0 }) != false else { throw .invalidSettings }
    }
}

public enum Joint2DEvents {
    /// Once per contiguous run of native over-threshold reports (awake joints only).
    public struct ThresholdExceeded: Event {
        public let jointOwner: Entity
        /// End-of-step values; Box2D's threshold may have been exceeded in an earlier substep.
        public let force: Vector2
        public let torque: Float
        public let didBreak: Bool
    }
}

extension PhysicsJoint2DDescriptor {
    public func withBreakSettings(_ settings: JointBreak2DSettings) throws(PhysicsJoint2DError) -> PhysicsJoint2DDescriptor {
        try settings.validate()
        return PhysicsJoint2DDescriptor(joint: joint, breakSettings: settings)
    }
}

@MainActor
extension PhysicsJoint2DComponent {
    public var isBroken: Bool { runtimeJoint?.isBroken ?? false }

    /// Broken constraints stay broken until explicitly reconnected or given a new descriptor.
    public mutating func reconnect() { jointDescriptor = jointDescriptor.replacingJoint(jointDescriptor.joint) }

    public mutating func updateBreakSettings(_ settings: JointBreak2DSettings) throws(PhysicsJoint2DError) {
        try settings.validate()
        guard let record = runtimeJoint, record.isConnected, record.descriptor === jointDescriptor else { throw .notConnected }
        b2Joint_SetForceThreshold(record.id, settings.forceThreshold ?? .greatestFiniteMagnitude)
        b2Joint_SetTorqueThreshold(record.id, settings.torqueThreshold ?? .greatestFiniteMagnitude)
        record.wasOverThreshold = false
        let updated = PhysicsJoint2DDescriptor(joint: jointDescriptor.joint, breakSettings: settings)
        record.descriptor = updated
        jointDescriptor = updated
        b2Joint_WakeBodies(record.id)
    }
}

struct JointThresholdNotice2D {
    let record: RuntimeJoint2D
    let event: Joint2DEvents.ThresholdExceeded
}

@MainActor
extension PhysicsWorld2D {
    /// Snapshot all native IDs and loads before removal/delivery can invalidate native event storage.
    func processJointEvents() {
        jointThresholdIDs.removeAll(keepingCapacity: true)
        jointThresholdNotices.removeAll(keepingCapacity: true)
        let events = unsafe b2World_GetJointEvents(worldId)
        if let pointer = unsafe events.jointEvents {
            for index in 0..<Int(unsafe events.count) {
                let id = unsafe pointer[index].jointId
                if b2Joint_IsValid(id) { jointThresholdIDs.insert(b2StoreJointId(id)) }
            }
        }
        for (owner, record) in jointRecords {
            let above = record.isConnected && jointThresholdIDs.contains(b2StoreJointId(record.id))
            if above, !record.wasOverThreshold, let entity = eventSource?.getEntityByID(owner) {
                let event = Joint2DEvents.ThresholdExceeded(
                    jointOwner: entity,
                    force: b2Joint_GetConstraintForce(record.id).asVector2,
                    torque: b2Joint_GetConstraintTorque(record.id),
                    didBreak: record.descriptor.breakSettings.removeOnBreak
                )
                jointThresholdNotices.append(JointThresholdNotice2D(record: record, event: event))
            }
            record.wasOverThreshold = above
        }
        jointThresholdNotices.sort { $0.event.jointOwner.id < $1.event.jointOwner.id }
        for notice in jointThresholdNotices where notice.event.didBreak {
            notice.record.isBroken = true
            notice.record.destroy()
        }
        for notice in jointThresholdNotices { send(notice.event) }
        jointThresholdNotices.removeAll(keepingCapacity: true)
    }
}
