//
//  Body2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/19/23.
//

import box2d
import Math

// An object that represents physics 2D body.
public final class Body2D {
    
    unowned let world: PhysicsWorld2D
    weak var entity: Entity?
    
    internal private(set) var debugMesh: Mesh?
    
    private(set) var ref: b2Body
    
    internal init(world: PhysicsWorld2D, ref: b2Body, entity: Entity) {
        self.world = world
        self.ref = ref
        self.entity = entity
    }
    
    deinit {
        self.world.destroyBody(self)
    }
    
    // FIXME: Should support multiple meshes inside
    func addFixture(for fixtureDef: b2FixtureDef) {
        var fixture = fixtureDef
        self.ref.CreateFixture(&fixture)
        self.debugMesh = self.getFixtureList().getMesh()
    }
    
    func getFixtureList() -> FixtureList {
        guard let list = self.ref.GetFixtureList() else {
            fatalError("Failed to get fixture list")
        }
        
        return FixtureList(list: list)
    }
    
    var massData: b2MassData {
        get {
            return ref.GetMassData()
        }
        
        set {
            withUnsafePointer(to: newValue) { ptr in
                self.ref.SetMassData(ptr)
            }
        }
    }
    
    func getPosition() -> Vector2 {
        return self.ref.GetPosition().pointee.asVector2
    }
    
    func getAngle() -> Float {
        return self.ref.GetAngle()
    }
    
    func getLinearVelocity() -> Vector2 {
        return self.ref.GetLinearVelocity().pointee.asVector2
    }
    
    func getWorldCenter() -> Vector2 {
        return self.ref.GetWorldCenter().pointee.asVector2
    }
    
    func setTransform(position: Vector2, angle: Float) {
        self.ref.SetTransform(position.b2Vec, angle)
    }
    
    /// Set the linear velocity of the center of mass.
    func setLinearVelocity(_ vector: Vector2) {
        self.ref.SetLinearVelocity(vector.b2Vec)
    }
    
    /// Apply a force at a world point. If the force is not applied at the center of mass, it will generate a torque and affect the angular velocity. This wakes up the body.
    func applyForce(force: Vector2, point: Vector2, wake: Bool) {
        self.ref.ApplyForce(force.b2Vec, point.b2Vec, wake)
    }
    
    /// Apply a force to the center of mass. This wakes up the body.
    func applyForceToCenter(_ force: Vector2, wake: Bool) {
        self.ref.ApplyForceToCenter(force.b2Vec, wake)
    }
    
    /// Apply an impulse at a point. This immediately modifies the velocity.
    /// It also modifies the angular velocity if the point of application is not at the center of mass. This wakes up the body.
    func applyLinearImpulse(_ impulse: Vector2, point: Vector2, wake: Bool) {
        self.ref.ApplyLinearImpulse(impulse.b2Vec, point.b2Vec, wake)
    }
    
    /// Apply a torque. This affects the angular velocity without affecting the linear velocity of the center of mass. This wakes up the body.
    func applyTorque(_ torque: Float, wake: Bool) {
        self.ref.ApplyTorque(torque, wake)
    }
    
    /// Get the world linear velocity of a world point attached to this body.
    /// - Parameter worldPoint: point in world coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    
    func getLinearVelocityFromWorldPoint(_ worldPoint: Vector2) -> Vector2 {
        return self.ref.GetLinearVelocityFromWorldPoint(worldPoint.b2Vec).asVector2
    }
    
    /// Get the world velocity of a local point.
    /// - Parameter localPoint: point in local coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    func getLinearVelocityFromLocalPoint(_ localPoint: Vector2) -> Vector2 {
        return self.ref.GetLinearVelocityFromLocalPoint(localPoint.b2Vec).asVector2
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
    
    let list: b2Fixture
    
    init(list: b2Fixture) {
        self.list = list
    }
    
    var filterData: b2Filter {
        get {
            return list.GetFilterData().pointee
        }
        
        set {
            list.SetFilterData(newValue)
        }
    }
    
    var body: b2Body {
        return self.list.GetBody()
    }
    
    var shape: BoxShape2D {
        return BoxShape2D(shape: list.GetShape())
    }
    
    var type: Box2DShapeType {
        
        return Box2DShapeType(rawValue: list.GetType().rawValue)!
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

class BoxShape2D {
    
    private(set) var shape: b2Shape
    
    init(shape: b2Shape) {
        self.shape = shape
    }
    
    var type: Box2DShapeType {
        return Box2DShapeType(rawValue: shape.GetType().rawValue)!
    }
    
    func getPolygonVertices() -> [Vector2] {
        guard self.type == .polygon else {
            return []
        }
        
        let polygonShape = Unmanaged.passUnretained(shape).toOpaque().assumingMemoryBound(to: b2PolygonShape.self)
        
        let vertices = withUnsafeBytes(of: polygonShape.pointee.m_vertices) { buffer in
            [Vector2](buffer.bindMemory(to: Vector2.self))
        }
        
        guard !vertices.isEmpty else {
            return []
        }
        
        return vertices
    }
    
    func getRadius() -> Float {
        return self.shape.m_radius
    }
}
