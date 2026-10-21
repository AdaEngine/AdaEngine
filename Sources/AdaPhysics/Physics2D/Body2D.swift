//
//  Body2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/19/23.
//

import AdaECS
import AdaTransform
import box2d
import Math

/// This class is used to hold a box2d body reference.
public final class Body2D: @unchecked Sendable {
    weak var world: PhysicsWorld2D?
    weak var entity: Entity?

    let bodyId: b2BodyId

    internal init(world: consuming PhysicsWorld2D, bodyId: b2BodyId, entity: consuming Entity) {
        self.world = world
        self.bodyId = bodyId
        self.entity = entity
    }

    deinit {
        world?.destroyBody(self)
    }

    @discardableResult
    func appendShape(
        _ shapeResource: Shape2DResource,
        transform: Transform,
        shapeDef: b2ShapeDef
    ) -> BoxShape2D {
        let shapeId = unsafe BoxShape2D.makeShape(
            for: shapeResource,
            transform: transform,
            shapeDef: shapeDef,
            bodyId: bodyId
        )
        return BoxShape2D(shape: shapeId)
    }

    var shapesCount: Int32 {
        b2Body_GetShapeCount(bodyId)
    }

    func getShapes() -> [BoxShape2D] {
        let shapes = UnsafeMutablePointer<b2ShapeId>.allocate(capacity: Int(shapesCount))
        unsafe b2Body_GetShapes(bodyId, shapes, shapesCount)
        return unsafe Array(UnsafeBufferPointer(start: shapes, count: Int(shapesCount)))
            .map {
                BoxShape2D(shape: $0)
            }
    }

    var gravityScale: Float {
        get {
            b2Body_GetGravityScale(bodyId)
        }
        set {
            b2Body_SetGravityScale(bodyId, newValue)
        }
    }

    var massData: b2MassData {
        get { b2Body_GetMassData(bodyId) }
        set { b2Body_SetMassData(bodyId, newValue) }
    }

    func getPosition() -> Vector2 {
        b2Body_GetPosition(bodyId).asVector2
    }

    func getAngle() -> Angle {
        Angle.radians(
            b2Rot_GetAngle(b2Body_GetRotation(bodyId))
        )
    }

    func getLinearVelocity() -> Vector2 {
        b2Body_GetLinearVelocity(bodyId).asVector2
    }

    func getWorldCenter() -> Vector2 {
        b2Body_GetWorldCenter(bodyId).asVector2
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
        return b2Body_GetWorldPointVelocity(bodyId, worldPoint.b2Vec).asVector2
    }

    /// Get the world velocity of a local point.
    /// - Parameter localPoint: point in local coordinates.
    /// - Returns: The world velocity of a point or zero if entity not attached to Physics2DWorld.
    func getLinearVelocityFromLocalPoint(_ localPoint: Vector2) -> Vector2 {
        return b2Body_GetLocalPointVelocity(bodyId, localPoint.b2Vec).asVector2
    }

    func setAngularVelocity(_ velocity: Float) {
        b2Body_SetAngularVelocity(bodyId, velocity)
    }

    func getAngularVelocity() -> Float {
        b2Body_GetAngularVelocity(bodyId)
    }
}

final class BoxShape2D {
    private let shape: b2ShapeId

    init(shape: consuming b2ShapeId) {
        self.shape = shape
    }

    @inline(__always)
    var bodyId: b2BodyId {
        b2Shape_GetBody(shape)
    }

    @inline(__always)
    var isValid: Bool {
        b2Shape_IsValid(shape)
    }

    @inline(__always)
    var isSensor: Bool {
        b2Shape_IsSensor(shape)
    }

    var body: Body2D? {
        guard let ptr = unsafe b2Body_GetUserData(bodyId) else {
            return nil
        }

        return unsafe Unmanaged<Body2D>.fromOpaque(ptr).takeUnretainedValue()
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

    func getMaterial() -> UInt64 {
        b2Shape_GetUserMaterial(shape)
    }

    func setMaterial(_ material: UInt64) {
        return b2Shape_SetUserMaterial(shape, material)
    }

    static func makeShape(
        for shape: Shape2DResource,
        transform: Transform,
        shapeDef: b2ShapeDef,
        bodyId: b2BodyId
    ) -> b2ShapeId {
        switch shape.fixture {
        case let .segment(line):
            return unsafe makeLine(line, kind: .segment, transform: transform, definition: shapeDef, body: bodyId)
        case let .chain(line):
            return unsafe makeLine(line, kind: .chain, transform: transform, definition: shapeDef, body: bodyId)
        case let .chainSegment(line):
            return unsafe makeLine(line, kind: .loose, transform: transform, definition: shapeDef, body: bodyId)
        case let .polygon(shape):
            guard let polygon = unsafe makePolygon(vertices: shape.verticies, offset: shape.offset, scale: transform.scale.xy) else {
                return b2_nullShapeId
            }
            return unsafe withUnsafePointer(to: shapeDef) { shapeDefPtr in
                unsafe withUnsafePointer(to: polygon) { polygonPtr in
                    unsafe b2CreatePolygonShape(bodyId, shapeDefPtr, polygonPtr)
                }
            }
        case let .circle(shape):
            var circle = b2Circle(center: (shape.offset * transform.scale.xy).b2Vec, radius: shape.radius * abs(transform.scale.x))
            return unsafe withUnsafePointer(to: shapeDef) { shapeDefPtr in
                unsafe b2CreateCircleShape(bodyId, shapeDefPtr, &circle)
            }
        case let .capsule(shape):
            let start = (shape.start + shape.offset) * transform.scale.xy
            let end = (shape.end + shape.offset) * transform.scale.xy
            let radius = shape.radius * max(abs(transform.scale.x), abs(transform.scale.y))
            guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite,
                radius.isFinite, radius > 0 else {
                return b2_nullShapeId
            }
            var capsule = b2Capsule(center1: start.b2Vec, center2: end.b2Vec, radius: radius)
            return unsafe withUnsafePointer(to: shapeDef) { unsafe b2CreateCapsuleShape(bodyId, $0, &capsule) }
        case let .roundedPolygon(shape):
            let radius = shape.radius * max(abs(transform.scale.x), abs(transform.scale.y))
            guard let polygon = unsafe makePolygon(vertices: shape.vertices, offset: shape.offset, scale: transform.scale.xy, radius: radius) else {
                return b2_nullShapeId
            }
            return unsafe withUnsafePointer(to: shapeDef) { definition in
                unsafe withUnsafePointer(to: polygon) { unsafe b2CreatePolygonShape(bodyId, definition, $0) }
            }
        case let .box(shape):
            guard let polygon = NativeBox2D.make(shape, scale: transform.scale.xy) else {
                return b2_nullShapeId
            }

            return unsafe withUnsafePointer(to: shapeDef) { shapeDefPtr in
                unsafe withUnsafePointer(to: polygon) { polygonPtr in
                    unsafe b2CreatePolygonShape(bodyId, shapeDefPtr, polygonPtr)
                }
            }
        }
    }

    private static func makePolygon(vertices: [Vector2], offset: Vector2, scale: Vector2, angle: Float = 0, radius: Float = 0) -> b2Polygon? {
        guard (3...Int(B2_MAX_POLYGON_VERTICES)).contains(vertices.count), angle.isFinite,
            radius.isFinite, radius >= 0 else {
            return nil
        }
        let cosine = Math.cos(angle)
        let sine = Math.sin(angle)
        let vertices = vertices.map { vertex in
            let rotated = Vector2(cosine * vertex.x - sine * vertex.y, sine * vertex.x + cosine * vertex.y)
            return ((rotated + offset) * scale).b2Vec
        }
        guard vertices.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            return nil
        }
        var hull = unsafe vertices.withUnsafeBufferPointer { buffer in
            unsafe b2ComputeHull(buffer.baseAddress, Int32(buffer.count))
        }
        guard hull.count >= 3 else {
            return nil
        }
        return unsafe b2MakePolygon(&hull, radius)
    }
}
