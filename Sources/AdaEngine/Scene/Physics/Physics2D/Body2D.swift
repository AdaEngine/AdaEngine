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
    
    private(set) var ref: b2BodyId
    
    internal init(world: PhysicsWorld2D, ref: b2BodyId, entity: Entity) {
        self.world = world
        self.ref = ref
        self.entity = entity
    }
    
    deinit {
        self.world.destroyBody(self)
    }
    
    func setNullBodyId() {
        self.ref = b2_nullBodyId
    }
    
    // FIXME: Should support multiple meshes inside
    func addFixture(for chainDef: b2ChainDef) {
        var chain = chainDef
        var chainId = b2CreateChain(self.ref, &chain)
        self.debugMesh = self.getFixtureList(with: shapeId).getMesh()
    }
    
    func getFixtureList(with chainId: b2ChainId) -> FixtureList {
        return FixtureList(list: b2Shape_Cha)
    }
    
    var massData: b2MassData {
        get {
            return b2Body_GetMassData(self.ref)
        }
        
        set {
            return b2Body_SetMassData(self.ref, newValue)
        }
    }
    
    func getPosition() -> Vector2 {
        return b2Body_GetPosition(self.ref).asVector2
    }
    
    func getAngle() -> Float {
        return b2Body_GetRotation(self.ref).s
    }
    
    func getLinearVelocity() -> Vector2 {
        return b2Body_GetLinearVelocity(self.ref).asVector2
    }
    
    func getWorldCenter() -> Vector2 {
        return b2Body_GetWorldCenterOfMass(self.ref).asVector2
    }
    
    func setTransform(position: Vector2, angle: Float) {
        return b2Body_SetTransform(self.ref, position.b2Vec, b2MakeRot(angle))
    }
    
    /// Set the linear velocity of the center of mass.
    func setLinearVelocity(_ vector: Vector2) {
        return b2Body_SetLinearVelocity(self.ref, vector.b2Vec)
    }
    
    /// Apply a force at a world point. If the force is not applied at the center of mass, it will generate a torque and affect the angular velocity. This wakes up the body.
    func applyForce(force: Vector2, point: Vector2, wake: Bool) {
        return b2Body_ApplyForce(self.ref, force.b2Vec, point.b2Vec, wake)
    }
    
    /// Apply a force to the center of mass. This wakes up the body.
    func applyForceToCenter(_ force: Vector2, wake: Bool) {
        return b2Body_ApplyForceToCenter(self.ref, force.b2Vec, wake)
    }
    
    /// Apply an impulse at a point. This immediately modifies the velocity.
    /// It also modifies the angular velocity if the point of application is not at the center of mass. This wakes up the body.
    func applyLinearImpulse(_ impulse: Vector2, point: Vector2, wake: Bool) {
        return b2Body_ApplyLinearImpulse(self.ref, impulse.b2Vec, point.b2Vec, wake)
    }
    
    /// Apply a torque. This affects the angular velocity without affecting the linear velocity of the center of mass. This wakes up the body.
    func applyTorque(_ torque: Float, wake: Bool) {
        return b2Body_ApplyTorque(self.ref, torque, wake)
    }
    
    /// Get the world linear velocity of a world point attached to this body.
    /// - Parameter worldPoint: point in world coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    
    /* TODO: - (d.lomaev) - check b2 api 
     // getLinearVelocityFromWorldPoint
     // getLinearVelocityFromLocalPoint
     */
    func getLinearVelocityFromWorldPoint(_ worldPoint: Vector2) -> Vector2 {
        return b2Body_GetLinearVelocity(self.ref).asVector2
    }
    
    /// Get the world velocity of a local point.
    /// - Parameter localPoint: point in local coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    func getLinearVelocityFromLocalPoint(_ localPoint: Vector2) -> Vector2 {
        return b2Body_GetLinearVelocity(self.ref).asVector2
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

class FixtureList {
    
    let list: b2ShapeId
    
    init(list: b2ShapeId) {
        self.list = list
    }
    
    var filterData: b2Filter {
        get {
            b2Shape_GetFilter(self.list)
        }
        
        set {
            b2Shape_SetFilter(self.list, newValue)
        }
    }
    
    var body: b2BodyId {
        return b2Shape_GetBody(self.list)
    }
    
    var shape: BoxShape2D {
        return BoxShape2D(shape: self.list)
    }
    
    var type: Box2DShapeType {
        return b2Shape_GetType(self.list).toBox2DShapeType()
    }
    
    func getMesh() -> Mesh? {
        guard self.type == .polygon else {
            return nil
        }
        
        let vertices = self.shape.getPolygonVertices().map { Vector3($0, 0) }
        var meshDesc = MeshDescriptor(name: "FixtureMesh")
        
        meshDesc.positions = MeshBuffer(vertices)
        // FIXME: We should support 8 vertices
        meshDesc.indicies = [
            0, 1, 2, 2, 3, 0
        ]
        meshDesc.primitiveTopology = .lineStrip
        
        return Mesh.generate(from: [meshDesc])
    }
}

enum Box2DShapeType: UInt32 {
    case circle = 0
    case edge = 1
    case polygon = 2
    case chain = 3
    case count = 4
}

extension b2ShapeType {
    func toBox2DShapeType() -> Box2DShapeType {
        guard let type = Box2DShapeType(rawValue: self.rawValue) else {
            fatalError("Can't cast box2d shape type to Ada type")
        }
        return type
    }
}

class BoxShape2D {
    
    private(set) var shape: b2ShapeId
    
    init(shape: b2ShapeId) {
        self.shape = shape
    }
    
    var type: Box2DShapeType {
        return b2Shape_GetType(self.shape).toBox2DShapeType()
    }
    
    func getPolygonVertices() -> [Vector2] {
        guard self.type == .polygon else {
            return []
        }
        
        let polygonShape = b2Shape_GetPolygon(self.shape)
        
        let vertices = withUnsafeBytes(of: polygonShape.vertices) { buffer in
            [Vector2](buffer.bindMemory(to: Vector2.self))
        }
        
        guard !vertices.isEmpty else {
            return []
        }
        
        return vertices
    }
    
    func getRadius() -> Float {
        return b2Shape_GetPolygon(self.shape).radius
    }
}
