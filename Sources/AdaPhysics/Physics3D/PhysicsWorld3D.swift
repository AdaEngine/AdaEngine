//
//  PhysicsWorld3D.swift
//  AdaEngine
//
//  Created by Codex on 7/6/26.
//

import AdaECS
import box3d
import Math

/// Box3D-backed 3D physics world.
public final class PhysicsWorld3D: Codable, @unchecked Sendable {

    private let worldId: b3WorldId

    public var gravity: Vector3 {
        get {
            b3World_GetGravity(worldId).asVector3
        }

        set {
            b3World_SetGravity(worldId, newValue.b3Vec)
        }
    }

    public var isSleepingEnabled: Bool {
        get {
            b3World_IsSleepingEnabled(worldId)
        }

        set {
            b3World_EnableSleeping(worldId, newValue)
        }
    }

    public init(gravity: Vector3 = [0, -9.81, 0]) {
        var worldDef = b3DefaultWorldDef()
        worldDef.gravity = gravity.b3Vec
        self.worldId = b3CreateWorld(&worldDef)
        b3World_EnableWarmStarting(worldId, true)
    }

    deinit {
        b3DestroyWorld(worldId)
    }

    public convenience init(from decoder: Decoder) throws {
        self.init()
    }

    public func encode(to encoder: Encoder) throws { }

    public func updateSimulation(_ deltaTime: Float, subStepCount: Int32 = 4) {
        b3World_Step(worldId, deltaTime, subStepCount)
    }

    func createBody(with definition: b3BodyDef, for entity: Entity) -> Body3D {
        let body = withUnsafePointer(to: definition) {
            b3CreateBody(self.worldId, $0)
        }
        let bodyWrapper = Body3D(world: self, bodyId: body, entity: entity)
        let pointer = Unmanaged.passUnretained(bodyWrapper).toOpaque()
        b3Body_SetUserData(body, pointer)
        return bodyWrapper
    }
}

extension Vector3 {
    var b3Vec: b3Vec3 {
        b3Vec3(x: self.x, y: self.y, z: self.z)
    }
}

extension b3Vec3 {
    var asVector3: Vector3 {
        Vector3(x: self.x, y: self.y, z: self.z)
    }
}

extension Quat {
    var b3Quat: box3d.b3Quat {
        box3d.b3Quat(v: b3Vec3(x: self.x, y: self.y, z: self.z), s: self.w)
    }
}

extension b3Quat {
    var asQuat: Quat {
        Quat(x: self.v.x, y: self.v.y, z: self.v.z, w: self.s)
    }
}

extension PhysicsBodyMode {
    var b3Type: b3BodyType {
        switch self {
        case .static: return b3_staticBody
        case .dynamic: return b3_dynamicBody
        case .kinematic: return b3_kinematicBody
        }
    }

    init(b3BodyType: b3BodyType) {
        switch b3BodyType {
        case b3_staticBody: self = .static
        case b3_dynamicBody: self = .dynamic
        case b3_kinematicBody: self = .kinematic
        default: self = .static
        }
    }
}
