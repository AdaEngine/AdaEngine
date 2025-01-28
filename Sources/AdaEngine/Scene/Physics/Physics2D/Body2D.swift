//
//  Body2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/19/23.
//

@_implementationOnly import box2d
import Math

// An object that represents physics 2D body.
public final class Body2D {
    
    unowned let world: PhysicsWorld2D
    weak var entity: Entity?
    
    internal private(set) var debugMesh: Mesh?
    
    let bodyId: b2BodyId

    internal init(world: PhysicsWorld2D, bodyId: b2BodyId, entity: Entity) {
        self.world = world
        self.bodyId = bodyId
        self.entity = entity
    }
    
    deinit {
        self.world.destroyBody(self)
    }
    
    // FIXME: Should support multiple meshes inside
//    func addFixture(for fixtureDef: b2FixtureDef) {
//        var fixture = fixtureDef
//        self.ref.CreateFixture(&fixture)
//        self.debugMesh = self.getFixtureList().getMesh()
//    }
    
//    func getFixtureList() -> FixtureList {
//        guard let list = self.ref.GetFixtureList() else {
//            fatalError("Failed to get fixture list")
//        }
//        
//        return FixtureList(list: list)
//    }

    @discardableResult
    func appendPolygonShape(
        _ polygon: b2Polygon,
        shapeDef: b2ShapeDef
    ) -> BoxShape2D {
        let shapeId = withUnsafePointer(to: shapeDef) { shapeDefPtr in
            withUnsafePointer(to: polygon) { polygonPtr in
                b2CreatePolygonShape(bodyId, shapeDefPtr, polygonPtr)
            }
        }

        return BoxShape2D(shape: shapeId)
    }

    var shapesCount: Int32 {
        b2Body_GetShapeCount(bodyId)
    }

    func getShapes() -> [BoxShape2D] {
        return Array<b2ShapeId>(unsafeUninitializedCapacity: Int(shapesCount)) { buffer, initializedCount in
            b2Body_GetShapes(bodyId, buffer.baseAddress, Int32(initializedCount))
        }.map {
            BoxShape2D(shape: $0)
        }
    }

    var massData: b2MassData {
        get {
            return b2Body_GetMassData(bodyId)
        }
        
        set {
            b2Body_SetMassData(bodyId, newValue)
        }
    }
    
    func getPosition() -> Vector2 {
        b2Body_GetPosition(bodyId).asVector2
    }

    // FIXME: Not correct
    func getAngle() -> Angle {
        Angle.radians(b2Body_GetRotation(bodyId).c)
    }
    
    func getLinearVelocity() -> Vector2 {
        b2Body_GetLinearVelocity(bodyId).asVector2
    }
    
    func getWorldCenter() -> Vector2 {
        b2Body_GetWorldCenterOfMass(bodyId).asVector2
    }
    
    func setTransform(position: Vector2, angle: Angle) {
        b2Body_SetTransform(bodyId, position.b2Vec, b2MakeRot(angle.radians))
    }
    
    /// Set the linear velocity of the center of mass.
    func setLinearVelocity(_ vector: Vector2) {
        b2Body_SetLinearVelocity(bodyId, vector.b2Vec)
    }
    
    /// Apply a force at a world point. If the force is not applied at the center of mass, it will generate a torque and affect the angular velocity. This wakes up the body.
    func applyForce(force: Vector2, point: Vector2, wake: Bool) {
        b2Body_ApplyForce(bodyId, force.b2Vec, point.b2Vec, wake)
    }
    
    /// Apply a force to the center of mass. This wakes up the body.
    func applyForceToCenter(_ force: Vector2, wake: Bool) {
        b2Body_ApplyForceToCenter(bodyId, force.b2Vec, wake)
    }
    
    /// Apply an impulse at a point. This immediately modifies the velocity.
    /// It also modifies the angular velocity if the point of application is not at the center of mass. This wakes up the body.
    func applyLinearImpulse(_ impulse: Vector2, point: Vector2, wake: Bool) {
        b2Body_ApplyLinearImpulse(bodyId, impulse.b2Vec, point.b2Vec, wake)
    }
    
    /// Apply a torque. This affects the angular velocity without affecting the linear velocity of the center of mass. This wakes up the body.
    func applyTorque(_ torque: Float, wake: Bool) {
        b2Body_ApplyTorque(bodyId, torque, wake)
    }
    
    /// Get the world linear velocity of a world point attached to this body.
    /// - Parameter worldPoint: point in world coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    
    func getLinearVelocityFromWorldPoint(_ worldPoint: Vector2) -> Vector2 {
        b2Body_GetLinearVelocity(bodyId).asVector2
//        return self.ref.GetLinearVelocityFromWorldPoint(worldPoint.b2Vec).asVector2
    }
    
    /// Get the world velocity of a local point.
    /// - Parameter localPoint: point in local coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    func getLinearVelocityFromLocalPoint(_ localPoint: Vector2) -> Vector2 {
        return b2Body_GetLinearVelocity(bodyId).asVector2
//        return self.ref.GetLinearVelocityFromLocalPoint(localPoint.b2Vec).asVector2
    }
}

public struct Body2DDefinition {
    public var bodyMode: PhysicsBodyMode = .static
    public var position: Vector2 = .zero
    public var angle: Float = 0
    public var gravityScale: Float = 1
    public var linearVelocity: Vector2 = .zero
    
    public var angularVelocity: Float = 0
    public var linearDamping: Float = 0.01
    public var angularDamping: Float = 0.05
    public var allowSleep: Bool = true
    public var awake: Bool = true
    public var fixedRotation: Bool = false
    public var bullet: Bool = false
    public var isEnabled = true
}

//class FixtureList {
//    
//    let list: b2Fixture
//
//    init(list: b2Fixture) {
//        self.list = list
//    }
//    
//    var filterData: b2Filter {
//        get {
//            return list.GetFilterData().pointee
//        }
//        
//        set {
//            list.SetFilterData(newValue)
//        }
//    }
//    
//    var body: b2BodyId {
////        return self.list.GetBody()
//    }
//    
//    var shape: BoxShape2D {
//        return BoxShape2D(shape: list.GetShape())
//    }
//    
//    var type: Box2DShapeType {
//        
//        return Box2DShapeType(rawValue: list.GetType().rawValue)!
//    }
//    
//    func getMesh() -> Mesh? {
//        guard self.type == .polygon else {
//            return nil
//        }
//        
//        let vertices = self.shape.getPolygonVertices().map { Vector3($0, 0) }
//        var meshDesc = MeshDescriptor(name: "FixtureMesh")
//        
//        meshDesc.positions = MeshBuffer(vertices)
//        // FIXME: We should support 8 vertices
//        meshDesc.indicies = [
//            0, 1, 2, 2, 3, 0
//        ]
//        meshDesc.primitiveTopology = .lineStrip
//        
//        return Mesh.generate(from: [meshDesc])
//    }
//}

final class BoxShape2D {

    private let shape: b2ShapeId

    init(shape: b2ShapeId) {
        self.shape = shape
    }

    @inline(__always)
    var bodyId: b2BodyId {
        b2Shape_GetBody(shape)
    }

    var body: Body2D? {
        guard let ptr = b2Body_GetUserData(bodyId) else {
            return nil
        }
        
        return Unmanaged<Body2D>.fromOpaque(ptr).takeUnretainedValue()
    }

    var filter: b2Filter {
        get {
            b2Shape_GetFilter(shape)
        }

        set {
            b2Shape_SetFilter(shape, newValue)
        }
    }

    var type: b2ShapeType {
        b2Shape_GetType(shape)
    }

    func getMaterial() -> Int32 {
        b2Shape_GetMaterial(shape)
    }

    func setMaterial(_ material: Int32) {
        return b2Shape_SetMaterial(shape, material)
    }

    static func makeB2Polygon(for shape: Shape2DResource, transform: Transform) -> b2Polygon {
        switch shape.fixture {
        case .polygon(let shape):
            var hull = shape.verticies.withUnsafeBytes { ptr in
                let baseAddress = ptr.assumingMemoryBound(to: b2Vec2.self).baseAddress
                return b2ComputeHull(baseAddress, Int32(shape.verticies.count))
            }

            return b2MakeOffsetPolygon(&hull, shape.offset.b2Vec, b2Rot_identity)
        case .circle(let shape):
            return b2MakeSquare(shape.radius * transform.scale.x)
        case .box(let shape):
            return b2MakeBox(
                transform.scale.x * shape.halfWidth,
                transform.scale.y * shape.halfWidth
            )
        }
    }
}
