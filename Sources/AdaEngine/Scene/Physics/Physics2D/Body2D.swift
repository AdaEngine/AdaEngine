//
//  Body2D.swift
//  
//
//  Created by v.prusakov on 3/19/23.
//

@_implementationOnly import AdaBox2d
import Math

public final class Body2D {
    
    unowned let world: PhysicsWorld2D
    weak var entity: Entity?
    
    internal private(set) var debugMesh: Mesh?
    
    private(set) var ref: OpaquePointer
    
    internal init(world: PhysicsWorld2D, ref: OpaquePointer, entity: Entity) {
        self.world = world
        self.ref = ref
        self.entity = entity
    }
    
    // FIXME: Should support multiple meshes inside
    func addFixture(for fixtureDef: b2_fixture_def) {
        b2_body_create_fixture(self.ref, fixtureDef)
        self.debugMesh = self.getFixtureList().getMesh()
    }
    
    func getFixtureList() -> FixtureList {
        let ref = b2_body_get_fixture_list(self.ref)!
        return FixtureList(ref: ref)
    }
    
    var massData: b2_mass_data {
        get {
            b2_body_get_mass_data(self.ref)
        }
        
        set {
            b2_body_set_mass_data(self.ref, newValue)
        }
    }
    
    func getPosition() -> Vector2 {
        return b2_body_get_position(self.ref).asVector2
    }
    
    func getAngle() -> Float {
        return b2_body_get_angle(self.ref)
    }
    
    func getLinearVelocity() -> Vector2 {
        return b2_body_get_linear_velocity(self.ref).asVector2
    }
    
    func getWorldCenter() -> Vector2 {
        return b2_body_get_world_center(self.ref).asVector2
    }
    
    func setTransform(position: Vector2, angle: Float) {
        b2_body_set_transform(self.ref, position.b2Vec, angle)
    }
    
    /// Set the linear velocity of the center of mass.
    func setLinearVelocity(_ vector: Vector2) {
        b2_body_set_linear_velocity(self.ref, vector.b2Vec)
    }
    
    /// Apply a force at a world point. If the force is not applied at the center of mass, it will generate a torque and affect the angular velocity. This wakes up the body.
    func applyForce(force: Vector2, point: Vector2, wake: Bool) {
        b2_body_apply_force(self.ref, force.b2Vec, point.b2Vec, wake)
    }
    
    /// Apply a force to the center of mass. This wakes up the body.
    func applyForceToCenter(_ force: Vector2, wake: Bool) {
        b2_body_apply_force_to_center(self.ref, force.b2Vec, wake)
    }
    
    /// Apply an impulse at a point. This immediately modifies the velocity.
    /// It also modifies the angular velocity if the point of application is not at the center of mass. This wakes up the body.
    func applyLinearImpulse(_ impulse: Vector2, point: Vector2, wake: Bool) {
        b2_body_apply_linear_impulse(self.ref, impulse.b2Vec, point.b2Vec, wake)
    }
    
    /// Apply a torque. This affects the angular velocity without affecting the linear velocity of the center of mass. This wakes up the body.
    func applyTorque(_ torque: Float, wake: Bool) {
        b2_body_apply_torque(self.ref, torque, wake)
    }
    
    /// Get the world linear velocity of a world point attached to this body.
    /// - Parameter worldPoint: point in world coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    
    func getLinearVelocityFromWorldPoint(_ worldPoint: Vector2) -> Vector2 {
        return b2_body_get_linear_velocity_from_world_point(self.ref, worldPoint.b2Vec).asVector2
    }
    
    /// Get the world velocity of a local point.
    /// - Parameter localPoint: point in local coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    func getLinearVelocityFromLocalPoint(_ localPoint: Vector2) -> Vector2 {
        return b2_body_get_linear_velocity_from_local_point(self.ref, localPoint.b2Vec).asVector2
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
    
    let ref: OpaquePointer
    
    init(ref: OpaquePointer) {
        self.ref = ref
    }
    
    deinit {
        self.ref.deallocate()
    }
    
    var filterData: b2_filter {
        get {
            return b2_fixture_get_filter_data(self.ref)
        }
        
        set {
            b2_fixture_set_filter_data(self.ref, newValue)
        }
    }
    
    var body: OpaquePointer {
        return b2_fixture_get_body(self.ref)
    }
    
    var shape: BoxShape2D {
        return BoxShape2D(ref: b2_fixture_get_shape(self.ref))
    }
    
    var type: Box2DShapeType {
        return Box2DShapeType(rawValue: b2_fixture_get_type(self.ref).rawValue)!
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
    
    private(set) var ref: OpaquePointer
    
    init(ref: OpaquePointer) {
        self.ref = ref
    }
    
    var type: Box2DShapeType {
        return Box2DShapeType(rawValue: b2_shape_get_type(self.ref).rawValue)!
    }
    
    deinit {
        self.ref.deallocate()
    }
    
    func getPolygonVertices() -> [Vector2] {
        guard self.type == .polygon else {
            return []
        }
        
        var count: UInt32 = 0
        var b2Vertices: UnsafeMutablePointer<b2_vec2>?
        b2_polygon_shape_get_vertices(self.ref, &b2Vertices, &count)
        
        // swiftlint:disable:next empty_count
        guard let b2Vertices, count > 0 else {
            return []
        }
        
        let vertices = UnsafeMutableRawPointer(b2Vertices).bindMemory(to: Vector2.self, capacity: Int(count))
        
        defer {
            b2Vertices.deallocate()
        }
        
        return Array(UnsafeBufferPointer(start: vertices, count: Int(count)))
    }
    
    func getRadius() -> Float {
        return b2_shape_get_radius(self.ref)
    }
}
