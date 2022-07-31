/**
 Copyright (c) 2006-2014 Erin Catto http://www.box2d.org
 Copyright (c) 2015 - Yohei Yoshihara
 
 This software is provided 'as-is', without any express or implied
 warranty.  In no event will the authors be held liable for any damages
 arising from the use of this software.
 
 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:
 
 1. The origin of this software must not be misrepresented; you must not
 claim that you wrote the original software. If you use this software
 in a product, an acknowledgment in the product documentation would be
 appreciated but is not required.
 
 2. Altered source versions must be plainly marked as such, and must not be
 misrepresented as being the original software.
 
 3. This notice may not be removed or altered from any source distribution.
 
 This version of box2d was developed by Yohei Yoshihara. It is based upon
 the original C++ code written by Erin Catto.
 */

/**
 @file
 Structures and functions used for computing contact points, distance
 queries, and TOI queries.
 */

public let b2_nullFeature = UInt8.max

public enum b2ContactFeatureType : UInt8, CustomStringConvertible {
    case vertex = 0
    case face = 1
    public var description: String {
        switch self {
        case .vertex: return "vertex"
        case .face: return "face"
        }
    }
}

/**
 The features that intersect to form the contact point
 This must be 4 bytes or less.
 */
public struct b2ContactFeature : CustomStringConvertible {
    /**
     Feature index on shapeA
     */
    public var indexA: UInt8 = 0
    /**
     Feature index on shapeB
     */
    public var indexB: UInt8 = 0
    /**
     The feature type on shapeA
     */
    public var typeA: b2ContactFeatureType = b2ContactFeatureType.vertex
    /**
     The feature type on shapeB
     */
    public var typeB: b2ContactFeatureType = b2ContactFeatureType.vertex
    
    public init() {}
    public mutating func setZero() {
        indexA = 0
        indexB = 0
        typeA = b2ContactFeatureType.vertex
        typeB = b2ContactFeatureType.vertex
    }
    public var description: String {
        return "b2ContactFeature[indexA=\(indexA), indexB=\(indexB), typeA=\(typeA), typeB=\(typeB)]"
    }
}

public func == (lhs: b2ContactFeature, rhs: b2ContactFeature) -> Bool {
    return lhs.indexA == rhs.indexA && lhs.indexB == rhs.indexB && lhs.typeA == rhs.typeA && lhs.typeB == rhs.typeB
}

/**
 A manifold point is a contact point belonging to a contact
 manifold. It holds details related to the geometry and dynamics
 of the contact points.
 The local point usage depends on the manifold type:
 -circles: the local center of circleB
 -faceA: the local center of cirlceB or the clip point of polygonB
 -faceB: the clip point of polygonA
 This structure is stored across time steps, so we keep it small.
 Note: the impulses are used for internal caching and may not
 provide reliable contact forces, especially for high speed collisions.
 */
open class b2ManifoldPoint : CustomStringConvertible {
    /**
     usage depends on manifold type
     */
    open var localPoint = b2Vec2()
    /**
     the non-penetration impulse
     */
    open var normalImpulse: b2Float = 0.0
    /**
     the friction impulse
     */
    open var tangentImpulse: b2Float = 0.0
    /**
     uniquely identifies a contact point between two shapes
     */
    open var id = b2ContactFeature()
    
    public init() {}
    public init(copyFrom: b2ManifoldPoint) {
        self.localPoint = copyFrom.localPoint
        self.normalImpulse = copyFrom.normalImpulse
        self.tangentImpulse = copyFrom.tangentImpulse
        self.id = copyFrom.id
    }
    open var description: String {
        return "b2ManifoldPoint[localPoint=\(localPoint), normalImpulse\(normalImpulse), tangentImpulse=\(tangentImpulse), id=\(id)]"
    }
}

public enum b2ManifoldType : CustomStringConvertible {
    case circles
    case faceA
    case faceB
    public var description: String {
        switch self {
        case .circles: return "circles"
        case .faceA: return "faceA"
        case .faceB: return "faceB"
        }
    }
}

/**
 A manifold for two touching convex shapes.
 Box2D supports multiple types of contact:
 - clip point versus plane with radius
 - point versus point with radius (circles)
 The local point usage depends on the manifold type:
 -circles: the local center of circleA
 -faceA: the center of faceA
 -faceB: the center of faceB
 Similarly the local normal usage:
 -circles: not used
 -faceA: the normal on polygonA
 -faceB: the normal on polygonB
 We store contacts in this way so that position correction can
 account for movement, which is critical for continuous physics.
 All contact scenarios must be expressed in one of these types.
 This structure is stored across time steps, so we keep it small.
 */
open class b2Manifold : CustomStringConvertible {
    /**
     the points of contact
     */
    open var points = [b2ManifoldPoint]()
    /**
     not use for Type::e_points
     */
    open var localNormal = b2Vec2()
    /**
     usage depends on manifold type
     */
    open var localPoint = b2Vec2()
    open var type = b2ManifoldType.circles
    /**
     the number of manifold points
     */
    open var pointCount : Int { return points.count }
    
    public init() {
    }
    public init(copyFrom: b2Manifold) {
        self.points = [b2ManifoldPoint]()
        self.points.reserveCapacity(copyFrom.points.count)
        for e in copyFrom.points {
            self.points.append(b2ManifoldPoint(copyFrom: e))
        }
        self.localNormal = copyFrom.localNormal
        self.localPoint = copyFrom.localPoint
        self.type = copyFrom.type
    }
    open var description: String {
        var s = String()
        s += "b2Manifold["
        s += "pointCount=\(pointCount), "
        s += "points={"
        for i in 0 ..< pointCount {
            if i != pointCount - 1 {
                s += "\(points[i]), "
            }
            else {
                s += "\(points[i])}, "
            }
        }
        s += "localNormal=\(localNormal), "
        s += "localPoint=\(localPoint), "
        s += "type=\(type)]"
        return s
    }
}

/**
 This is used to compute the current state of a contact manifold.
 */
open class b2WorldManifold : CustomStringConvertible {
    public init() {}
    /**
     world vector pointing from A to B
     */
    open var normal = b2Vec2()
    /**
     world contact point (point of intersection)
     */
    open var points = [b2Vec2](repeating: b2Vec2(0, 0), count: b2_maxManifoldPoints)
    /**
     a negative value indicates overlap, in meters
     */
    open var separations = [Float](repeating: 0, count: b2_maxManifoldPoints)
    /**
     Evaluate the manifold with supplied transforms. This assumes
     modest motion from the original state. This does not change the
     point count, impulses, etc. The radii must come from the shapes
     that generated the manifold.
     */
    open func initialize(manifold: b2Manifold,
                         transformA xfA: b2Transform, radiusA: b2Float,
                         transformB xfB: b2Transform, radiusB: b2Float) {
        if manifold.pointCount == 0 {
            return
        }
        
        switch manifold.type {
        case .circles:
            normal.set(1.0, 0.0)
            let pointA = b2Mul(xfA, manifold.localPoint)
            let pointB = b2Mul(xfB, manifold.points[0].localPoint)
            if b2DistanceSquared(pointA, pointB) > b2_epsilon * b2_epsilon {
                normal = pointB - pointA
                normal.normalize()
            }
            
            let cA = pointA + radiusA * normal
            let cB = pointB - radiusB * normal
            points[0] = 0.5 * (cA + cB)
            separations[0] = b2Dot(cB - cA, normal)
            
        case .faceA:
            normal = b2Mul(xfA.q, manifold.localNormal)
            let planePoint = b2Mul(xfA, manifold.localPoint)
            
            for i in 0 ..< manifold.pointCount {
                let clipPoint = b2Mul(xfB, manifold.points[i].localPoint)
                let cA = clipPoint + (radiusA - b2Dot(clipPoint - planePoint, normal)) * normal
                let cB = clipPoint - radiusB * normal
                points[i] = 0.5 * (cA + cB)
                separations[i] = b2Dot(cB - cA, normal)
            }
            
        case .faceB:
            normal = b2Mul(xfB.q, manifold.localNormal)
            let planePoint = b2Mul(xfB, manifold.localPoint)
            
            for i in 0 ..< manifold.pointCount {
                let clipPoint = b2Mul(xfA, manifold.points[i].localPoint)
                let cB = clipPoint + (radiusB - b2Dot(clipPoint - planePoint, normal)) * normal
                let cA = clipPoint - radiusA * normal
                points[i] = 0.5 * (cA + cB)
                separations[i] = b2Dot(cA - cB, normal)
            }
            
            // Ensure normal points from A to B.
            normal = -normal
        }
    }
    open var description: String {
        return "b2WorldManifold[normal=\(normal), points=\(points), separations=\(separations)]"
    }
}

/**
 This is used for determining the state of contact points.
 */
public enum b2PointState : CustomStringConvertible {
    /**
     point does not exist
     */
    case nullState
    /**
     point was added in the update
     */
    case addState
    /**
     point persisted across the update
     */
    case persistState
    /**
     point was removed in the update
     */
    case removeState
    
    public var description: String {
        switch self {
        case .nullState: return "nullState"
        case .addState: return "addState"
        case .persistState: return "persistState"
        case .removeState: return "removeState"
        }
    }
}

/**
 Compute the point states given two manifolds. The states pertain to the transition from manifold1
 to manifold2. So state1 is either persist or remove while state2 is either add or persist.
 */
public func b2GetPointStates(manifold1: b2Manifold, manifold2: b2Manifold)
-> (state1: [b2PointState], state2: [b2PointState]) {
    var state1 = [b2PointState]()
    var state2 = [b2PointState]()
    
    // Detect persists and removes.
    for p1 in manifold1.points {
        var found = false
        for p2 in manifold2.points {
            if p2.id == p1.id {
                found = true
                break
            }
        }
        state1.append(found ? b2PointState.persistState : b2PointState.removeState)
    }
    
    // Detect persists and adds.
    for p2 in manifold2.points {
        var found = false
        for p1 in manifold1.points {
            if p1.id == p2.id {
                found = true
                break
            }
        }
        state2.append(found ? b2PointState.persistState : b2PointState.addState)
    }
    assert(state1.count == manifold1.pointCount)
    assert(state2.count == manifold2.pointCount)
    return (state1, state2)
}

/**
 Used for computing contact manifolds.
 */
public struct b2ClipVertex : CustomStringConvertible {
    public init() {}
    public var v = b2Vec2()
    public var id = b2ContactFeature()
    public var description: String {
        return "b2ClipVertex[v=\(v), id=\(id)]"
    }
}

/**
 Ray-cast input data. The ray extends from p1 to p1 + maxFraction * (p2 - p1).
 */
public struct b2RayCastInput : CustomStringConvertible {
    public init() {}
    public var p1 = b2Vec2(), p2 = b2Vec2()
    public var maxFraction: b2Float = 0
    public var description: String {
        return "b2RayCastInput[p1=\(p1), p2=\(p2), maxFraction=\(maxFraction)]"
    }
}

/**
 Ray-cast output data. The ray hits at p1 + fraction * (p2 - p1), where p1 and p2
 come from b2RayCastInput.
 */
public struct b2RayCastOutput : CustomStringConvertible {
    public init() {}
    public var normal = b2Vec2()
    public var fraction: b2Float = 0
    public var description: String {
        return "b2RayCastOutput[normal=\(normal), fraction=\(fraction)]"
    }
}

/**
 An axis aligned bounding box.
 */
public struct b2AABB : CustomStringConvertible {
    public var lowerBound = b2Vec2()	///< the lower vertex
    public var upperBound = b2Vec2()	///< the upper vertex
    
    public init() {}
    public init(lowerBound: b2Vec2, upperBound: b2Vec2) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
    /**
     Verify that the bounds are sorted.
     */
    public var isValid: Bool {
        let d = upperBound - lowerBound
        var valid = d.x >= 0.0 && d.y >= 0.0
        valid = valid && lowerBound.isValid() && upperBound.isValid()
        return valid
    }
    
    /// Get the center of the AABB.
    public var center: b2Vec2 {
        return 0.5 * (lowerBound + upperBound)
    }
    
    /// Get the extents of the AABB (half-widths).
    public var extents: b2Vec2 {
        return 0.5 * (upperBound - lowerBound)
    }
    
    /// Get the perimeter length
    public var perimeter: b2Float {
        let wx = upperBound.x - lowerBound.x
        let wy = upperBound.y - lowerBound.y
        return 2.0 * (wx + wy)
    }
    
    /// Combine an AABB into this one.
    public mutating func combine(_ aabb: b2AABB) {
        lowerBound = b2Min(lowerBound, aabb.lowerBound)
        upperBound = b2Max(upperBound, aabb.upperBound)
    }
    
    /// Combine two AABBs into this one.
    public mutating func combine(_ aabb1: b2AABB, _ aabb2: b2AABB) {
        lowerBound = b2Min(aabb1.lowerBound, aabb2.lowerBound)
        upperBound = b2Max(aabb1.upperBound, aabb2.upperBound)
    }
    
    /// Does this aabb contain the provided AABB.
    public func contains(_ aabb: b2AABB) -> Bool {
        var result = true
        result = result && lowerBound.x <= aabb.lowerBound.x
        result = result && lowerBound.y <= aabb.lowerBound.y
        result = result && aabb.upperBound.x <= upperBound.x
        result = result && aabb.upperBound.y <= upperBound.y
        return result
    }
    
    public func rayCast(_ input: b2RayCastInput) -> b2RayCastOutput? {
        var tmin = b2_minFloat
        var tmax = b2_maxFloat
        
        let p = input.p1
        let d = input.p2 - input.p1
        let absD = b2Abs(d)
        
        var normal = b2Vec2()
        
        for i in 0 ..< 2 {
            if absD[i] < b2_epsilon {
                // Parallel.
                if p[i] < lowerBound[i] || upperBound[i] < p[i] {
                    return nil
                }
            }
            else {
                let inv_d = 1.0 / d[i]
                var t1 = (lowerBound[i] - p[i]) * inv_d
                var t2 = (upperBound[i] - p[i]) * inv_d
                
                // Sign of the normal vector.
                var s: b2Float = -1.0
                
                if t1 > t2 {
                    swap(&t1, &t2)
                    s = 1.0
                }
                
                // Push the min up
                if t1 > tmin {
                    normal.setZero()
                    normal[i] = s
                    tmin = t1
                }
                
                // Pull the max down
                tmax = min(tmax, t2)
                
                if tmin > tmax {
                    return nil
                }
            }
        }
        
        // Does the ray start inside the box?
        // Does the ray intersect beyond the max fraction?
        if tmin < 0.0 || input.maxFraction < tmin {
            return nil
        }
        
        // Intersection.
        var output = b2RayCastOutput()
        output.fraction = tmin
        output.normal = normal
        return output
    }
    public var description: String {
        return "b2AABB[lowerBound=\(lowerBound), upperBound=\(upperBound)]"
    }
}


/// Clipping for contact manifolds.
/// Sutherland-Hodgman clipping.
public func b2ClipSegmentToLine(inputVertices vIn: [b2ClipVertex], normal: b2Vec2, offset: b2Float, vertexIndexA: Int)
-> [b2ClipVertex] {
    assert(vIn.count == 2)
    var vOut = [b2ClipVertex]()
    
    // Calculate the distance of end points to the line
    let distance0 = b2Dot(normal, vIn[0].v) - offset
    let distance1 = b2Dot(normal, vIn[1].v) - offset
    
    // If the points are behind the plane
    if distance0 <= 0.0 {
        vOut.append(vIn[0])
    }
    if distance1 <= 0.0 {
        vOut.append(vIn[1])
    }
    
    // If the points are on different sides of the plane
    if distance0 * distance1 < 0.0 {
        // Find intersection point of edge and plane
        let interp = distance0 / (distance0 - distance1)
        var v = b2ClipVertex()
        v.v = vIn[0].v + interp * (vIn[1].v - vIn[0].v)
        
        // VertexA is hitting edgeB.
        v.id.indexA = UInt8(vertexIndexA)
        v.id.indexB = vIn[0].id.indexB
        v.id.typeA = b2ContactFeatureType.vertex
        v.id.typeB = b2ContactFeatureType.face
        vOut.append(v)
    }
    
    return vOut
}

/// Determine if two generic shapes overlap.
public func b2TestOverlap(shapeA: b2Shape, indexA: Int,
                          shapeB: b2Shape, indexB: Int,
                          transformA xfA: b2Transform, transformB xfB: b2Transform) -> Bool {
    var input = b2DistanceInput()
    input.proxyA.set(shapeA, indexA)
    input.proxyB.set(shapeB, indexB)
    input.transformA = xfA
    input.transformB = xfB
    input.useRadii = true
    
    var cache = b2SimplexCache()
    cache.count = 0
    
    var output = b2DistanceOutput()
    b2Distance(&output, cache: &cache, input: input)
    return output.distance < 10.0 * b2_epsilon
}

public func b2TestOverlap(_ a: b2AABB, _ b: b2AABB) -> Bool {
    let d1 = b.lowerBound - a.upperBound
    let d2 = a.lowerBound - b.upperBound
    
    if d1.x > 0.0 || d1.y > 0.0 {
        return false
    }
    
    if d2.x > 0.0 || d2.y > 0.0 {
        return false
    }
    
    return true
}
