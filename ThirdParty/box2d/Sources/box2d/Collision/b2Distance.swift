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

/// A distance proxy is used by the GJK algorithm.
/// It encapsulates any shape.
open class b2DistanceProxy: CustomStringConvertible {
    public init() {}
    public init(shape: b2Shape, index: Int) {
        set(shape, index)
    }
    
    /// Initialize the proxy using the given shape. The shape
    /// must remain in scope while the proxy is in use.
    open func set(_ shape: b2Shape, _ index: Int) {
        switch shape.type {
        case .circle:
            let circle = shape as! b2CircleShape
            m_vertices = circle.m_p_
            m_count = 1
            m_radius = circle.m_radius
            
        case .polygon:
            let polygon = shape as! b2PolygonShape
            m_vertices = polygon.m_vertices
            m_count = polygon.m_count
            m_radius = polygon.m_radius
            
        case .chain:
            let chain = shape as! b2ChainShape
            assert(0 <= index && index < chain.m_count)
            
            m_buffer[0] = chain.m_vertices[index]
            if index + 1 < chain.m_count {
                m_buffer[1] = chain.m_vertices[index + 1]
            }
            else {
                m_buffer[1] = chain.m_vertices[0]
            }
            
            m_vertices = m_buffer
            m_count = 2
            m_radius = chain.m_radius
            
        case .edge:
            let edge = shape as! b2EdgeShape
            m_vertices = edge.m_vertices
            m_count = 2
            m_radius = edge.m_radius
            
        default:
            assert(false)
        }
    }
    
    /// Get the supporting vertex index in the given direction.
    open func getSupport(_ d: b2Vec2) -> Int {
        var bestIndex = 0
        var bestValue = b2Dot(m_vertices![0], d)
        for i in 1 ..< m_count {
            let value = b2Dot(m_vertices![i], d)
            if value > bestValue {
                bestIndex = i
                bestValue = value
            }
        }
        
        return bestIndex
    }
    
    /// Get the supporting vertex in the given direction.
    open func getSupportVertex(_ d: b2Vec2) -> b2Vec2 {
        var bestIndex = 0
        var bestValue = b2Dot(m_vertices![0], d)
        for i in 1 ..< m_count {
            let value = b2Dot(m_vertices![i], d)
            if value > bestValue {
                bestIndex = i
                bestValue = value
            }
        }
        
        return m_vertices![bestIndex]
    }
    
    /// Get the vertex count.
    open func getVertexCount() -> Int {
        return m_count
    }
    
    /// Get a vertex by index. Used by b2Distance.
    open func getVertex(_ index: Int) -> b2Vec2 {
        assert(0 <= index && index < m_count)
        return m_vertices![index]
    }
    
    open var description: String {
        return "b2DistanceProxy[vertices=\(m_vertices!), count=\(m_count), radius=\(m_radius)]"
    }
    
    open var m_buffer = b2Array<b2Vec2>(count: 2, repeatedValue: b2Vec2())
    open var m_vertices: b2Array<b2Vec2>? = nil
    open var m_count = 0
    open var m_radius: b2Float = 0
}

class b2SimplexVertex : CustomStringConvertible {
    var wA = b2Vec2()		// support point in proxyA
    var wB = b2Vec2()		// support point in proxyB
    var w = b2Vec2()		// wB - wA
    var a: b2Float = 0	// barycentric coordinate for closest point
    var indexA = 0	    // wA index
    var indexB = 0	    // wB index
    func set(_ other: b2SimplexVertex) {
        self.wA = other.wA
        self.wB = other.wB
        self.w = other.w
        self.a = other.a
        self.indexA = other.indexA
        self.indexB = other.indexB
    }
    var description: String {
        return "{wA=\(wA),wB=\(wB),w=\(w),a=\(a),indexA=\(indexA),indexB=\(indexB)}"
    }
}

struct b2Simplex : CustomStringConvertible {
    init() {
        for _ in 0 ..< 3 {
            m_v.append(b2SimplexVertex())
        }
    }
    mutating func readCache(_ cache: b2SimplexCache,
                            _ proxyA: b2DistanceProxy, _ transformA: b2Transform,
                            _ proxyB: b2DistanceProxy, _ transformB: b2Transform)
    {
        assert(cache.count <= 3)
        
        // Copy data from cache.
        m_count = Int(cache.count)
        //var vertices = m_v
        for i in 0 ..< m_count {
            let v = m_v[i]
            v.indexA = Int(cache.indexA[i])
            v.indexB = Int(cache.indexB[i])
            let wALocal = proxyA.getVertex(v.indexA)
            let wBLocal = proxyB.getVertex(v.indexB)
            v.wA = b2Mul(transformA, wALocal)
            v.wB = b2Mul(transformB, wBLocal)
            v.w = v.wB - v.wA
            v.a = 0.0
        }
        
        // Compute the new simplex metric, if it is substantially different than
        // old metric then flush the simplex.
        if m_count > 1 {
            let metric1 = cache.metric
            let metric2 = getMetric()
            if metric2 < 0.5 * metric1 || 2.0 * metric1 < metric2 || metric2 < b2_epsilon {
                // Reset the simplex.
                m_count = 0
            }
        }
        
        // If the cache is empty or invalid ...
        if m_count == 0 {
            let v = m_v[0]
            v.indexA = 0
            v.indexB = 0
            let wALocal = proxyA.getVertex(0)
            let wBLocal = proxyB.getVertex(0)
            v.wA = b2Mul(transformA, wALocal)
            v.wB = b2Mul(transformB, wBLocal)
            v.w = v.wB - v.wA
            v.a = 1.0
            m_count = 1
        }
    }
    
    func writeCache(_ cache: inout b2SimplexCache) {
        cache.metric = getMetric()
        cache.count = UInt16(m_count)
        for i in 0 ..< m_count {
            cache.indexA[i] = UInt8(m_v[i].indexA)
            cache.indexB[i] = UInt8(m_v[i].indexB)
        }
    }
    
    func getSearchDirection() -> b2Vec2 {
        switch (m_count) {
        case 1:
            return -m_v1.w
            
        case 2:
            let e12 = m_v2.w - m_v1.w
            let sgn = b2Cross(e12, -m_v1.w)
            if sgn > 0.0 {
                // Origin is left of e12.
                return b2Cross(1.0, e12)
            }
            else {
                // Origin is right of e12.
                return b2Cross(e12, 1.0)
            }
            
        default:
            assert(false)
            return b2Vec2_zero
        }
    }
    
    func getClosestPoint() -> b2Vec2 {
        switch (m_count) {
        case 0:
            assert(false)
            return b2Vec2_zero
            
        case 1:
            return m_v1.w
            
        case 2:
            return m_v1.a * m_v1.w + m_v2.a * m_v2.w
            
        case 3:
            return b2Vec2_zero
            
        default:
            assert(false)
            return b2Vec2_zero
        }
    }
    
    func getWitnessPoints() -> (pA: b2Vec2, pB: b2Vec2) {
        var pA: b2Vec2
        var pB: b2Vec2
        switch (m_count) {
        case 0:
            fatalError("illegal state")
            
        case 1:
            pA = m_v1.wA
            pB = m_v1.wB
            
        case 2:
            pA = m_v1.a * m_v1.wA + m_v2.a * m_v2.wA
            pB = m_v1.a * m_v1.wB + m_v2.a * m_v2.wB
            
        case 3:
            pA = m_v1.a * m_v1.wA + m_v2.a * m_v2.wA + m_v3.a * m_v3.wA
            pB = pA
            
        default:
            fatalError("illegal state")
        }
        return (pA, pB)
    }
    
    func getMetric() -> b2Float {
        switch (m_count) {
        case 0:
            assert(false)
            return 0.0
            
        case 1:
            return 0.0
            
        case 2:
            return b2Distance(m_v1.w, m_v2.w)
            
        case 3:
            return b2Cross(m_v2.w - m_v1.w, m_v3.w - m_v1.w)
            
        default:
            assert(false)
            return 0.0
        }
    }
    
    // Solve a line segment using barycentric coordinates.
    //
    // p = a1 * w1 + a2 * w2
    // a1 + a2 = 1
    //
    // The vector from the origin to the closest point on the line is
    // perpendicular to the line.
    // e12 = w2 - w1
    // dot(p, e) = 0
    // a1 * dot(w1, e) + a2 * dot(w2, e) = 0
    //
    // 2-by-2 linear system
    // [1      1     ][a1] = [1]
    // [w1.e12 w2.e12][a2] = [0]
    //
    // Define
    // d12_1 =  dot(w2, e12)
    // d12_2 = -dot(w1, e12)
    // d12 = d12_1 + d12_2
    //
    // Solution
    // a1 = d12_1 / d12
    // a2 = d12_2 / d12
    mutating func solve2() {
        let w1 = m_v1.w
        let w2 = m_v2.w
        let e12 = w2 - w1
        
        // w1 region
        let d12_2 = -b2Dot(w1, e12)
        if d12_2 <= 0.0 {
            // a2 <= 0, so we clamp it to 0
            m_v1.a = 1.0
            m_count = 1
            return
        }
        
        // w2 region
        let d12_1 = b2Dot(w2, e12)
        if d12_1 <= 0.0 {
            // a1 <= 0, so we clamp it to 0
            m_v2.a = 1.0
            m_count = 1
            m_v1 = m_v2
            return
        }
        
        // Must be in e12 region.
        let inv_d12 = 1.0 / (d12_1 + d12_2)
        m_v1.a = d12_1 * inv_d12
        m_v2.a = d12_2 * inv_d12
        m_count = 2
    }
    
    // Possible regions:
    // - points[2]
    // - edge points[0]-points[2]
    // - edge points[1]-points[2]
    // - inside the triangle
    mutating func solve3() {
        let w1 = m_v1.w
        let w2 = m_v2.w
        let w3 = m_v3.w
        
        // Edge12
        // [1      1     ][a1] = [1]
        // [w1.e12 w2.e12][a2] = [0]
        // a3 = 0
        let e12 = w2 - w1
        let w1e12 = b2Dot(w1, e12)
        let w2e12 = b2Dot(w2, e12)
        let d12_1 = w2e12
        let d12_2 = -w1e12
        
        // Edge13
        // [1      1     ][a1] = [1]
        // [w1.e13 w3.e13][a3] = [0]
        // a2 = 0
        let e13 = w3 - w1
        let w1e13 = b2Dot(w1, e13)
        let w3e13 = b2Dot(w3, e13)
        let d13_1 = w3e13
        let d13_2 = -w1e13
        
        // Edge23
        // [1      1     ][a2] = [1]
        // [w2.e23 w3.e23][a3] = [0]
        // a1 = 0
        let e23 = w3 - w2
        let w2e23 = b2Dot(w2, e23)
        let w3e23 = b2Dot(w3, e23)
        let d23_1 = w3e23
        let d23_2 = -w2e23
        
        // Triangle123
        let n123 = b2Cross(e12, e13)
        
        let d123_1 = n123 * b2Cross(w2, w3)
        let d123_2 = n123 * b2Cross(w3, w1)
        let d123_3 = n123 * b2Cross(w1, w2)
        
        // w1 region
        if d12_2 <= 0.0 && d13_2 <= 0.0 {
            m_v1.a = 1.0
            m_count = 1
            return
        }
        
        // e12
        if d12_1 > 0.0 && d12_2 > 0.0 && d123_3 <= 0.0 {
            let inv_d12 = 1.0 / (d12_1 + d12_2)
            m_v1.a = d12_1 * inv_d12
            m_v2.a = d12_2 * inv_d12
            m_count = 2
            return
        }
        
        // e13
        if d13_1 > 0.0 && d13_2 > 0.0 && d123_2 <= 0.0 {
            let inv_d13 = 1.0 / (d13_1 + d13_2)
            m_v1.a = d13_1 * inv_d13
            m_v3.a = d13_2 * inv_d13
            m_count = 2
            m_v2 = m_v3
            return
        }
        
        // w2 region
        if d12_1 <= 0.0 && d23_2 <= 0.0 {
            m_v2.a = 1.0
            m_count = 1
            m_v1 = m_v2
            return
        }
        
        // w3 region
        if d13_1 <= 0.0 && d23_1 <= 0.0 {
            m_v3.a = 1.0
            m_count = 1
            m_v1 = m_v3
            return
        }
        
        // e23
        if d23_1 > 0.0 && d23_2 > 0.0 && d123_1 <= 0.0 {
            let inv_d23 = 1.0 / (d23_1 + d23_2)
            m_v2.a = d23_1 * inv_d23
            m_v3.a = d23_2 * inv_d23
            m_count = 2
            m_v1 = m_v3
            return
        }
        
        // Must be in triangle123
        let inv_d123 = 1.0 / (d123_1 + d123_2 + d123_3)
        m_v1.a = d123_1 * inv_d123
        m_v2.a = d123_2 * inv_d123
        m_v3.a = d123_3 * inv_d123
        m_count = 3
    }
    
    var description: String {
        if m_count == 0 {
            return "b2Simplex[v[0]={}]"
        }
        else if m_count == 1 {
            return "b2Simplex[v[1]={\(m_v[0])}]"
        }
        else if m_count == 2 {
            return "b2Simplex[v[2]={\(m_v[0]),\(m_v[1])}]"
        }
        else {
            return "b2Simplex[v[3]={\(m_v[0]),\(m_v[1]),\(m_v[2])}]"
        }
    }
    
    //    var m_v1 = b2SimplexVertex(), m_v2 = b2SimplexVertex(), m_v3 = b2SimplexVertex()
    var m_v = [b2SimplexVertex]() //(count: 3, repeatedValue: b2SimplexVertex())
    var m_v1: b2SimplexVertex {
        get {
            return m_v[0]
        }
        set {
            m_v[0].set(newValue)
        }
    }
    var m_v2: b2SimplexVertex {
        get {
            return m_v[1]
        }
        set {
            m_v[1].set(newValue)
        }
    }
    var m_v3: b2SimplexVertex {
        get {
            return m_v[2]
        }
        set {
            m_v[2].set(newValue)
        }
    }
    var m_count = 0
}


/// Used to warm start b2Distance.
/// Set count to zero on first call.
public struct b2SimplexCache : CustomStringConvertible {
    public init() {}
    public var metric: b2Float = 0		///< length or area
    public var count = UInt16(0)
    public var indexA = [UInt8](repeating: 0, count: 3)	///< vertices on shape A
    public var indexB = [UInt8](repeating: 0, count: 3)	///< vertices on shape B
    public var description: String {
        return "b2SimplexCache[metric=\(metric),count=\(count),indexA=\(indexA[0]),\(indexA[1]),\(indexA[2]),indexB=\(indexB[0]),\(indexB[1]),\(indexB[2])]"
    }
}

/// Input for b2Distance.
/// You have to option to use the shape radii
/// in the computation. Even
public struct b2DistanceInput : CustomStringConvertible {
    public init() {}
    public var description: String {
        return "b2DistanceInput[proxyA=\(proxyA),proxyB=\(proxyB),transformA=\(transformA),transformB=\(transformB),useRadii=\(useRadii)]"
    }
    public var proxyA = b2DistanceProxy()
    public var proxyB = b2DistanceProxy()
    public var transformA = b2Transform()
    public var transformB = b2Transform()
    public var useRadii = false
}

/// Output for b2Distance.
public struct b2DistanceOutput : CustomStringConvertible {
    public init() {}
    public var description: String {
        return "b2DistanceOutput[pointA=\(pointA),pointB=\(pointB),distance=\(distance),iterations=\(iterations)]"
    }
    public var pointA = b2Vec2()  ///< closest point on shapeA
    public var pointB = b2Vec2()  ///< closest point on shapeB
    public var distance: b2Float = 0
    public var iterations = 0     ///< number of GJK iterations used
}

/// Compute the closest points between two shapes. Supports any combination of:
/// b2CircleShape, b2PolygonShape, b2EdgeShape. The simplex cache is input/output.
/// On the first call set b2SimplexCache.count to zero.
public func b2Distance(_ output: inout b2DistanceOutput, cache: inout b2SimplexCache, input: b2DistanceInput) {
    b2_gjkCalls += 1
    
    let proxyA = input.proxyA
    let proxyB = input.proxyB
    
    let transformA = input.transformA
    let transformB = input.transformB
    
    // Initialize the simplex.
    var simplex = b2Simplex()
    simplex.readCache(cache, proxyA, transformA, proxyB, transformB)
    
    // Get simplex vertices as an array.
    //var vertices = simplex.m_v
    let k_maxIters = 20
    
    // These store the vertices of the last simplex so that we
    // can check for duplicates and prevent cycling.
    var saveA = [Int](repeating: 0, count: 3), saveB = [Int](repeating: 0, count: 3)
    var saveCount = 0
    
    var distanceSqr1 = b2_maxFloat
    var distanceSqr2 = distanceSqr1
    
    // Main iteration loop.
    var iter = 0
    while iter < k_maxIters {
        // Copy simplex so we can identify duplicates.
        saveCount = simplex.m_count
        for i in 0 ..< saveCount {
            saveA[i] = simplex.m_v[i].indexA
            saveB[i] = simplex.m_v[i].indexB
        }
        
        switch simplex.m_count {
        case 1:
            break
        case 2:
            simplex.solve2()
        case 3:
            simplex.solve3()
        default:
            assert(false)
        }
        
        // If we have 3 points, then the origin is in the corresponding triangle.
        if simplex.m_count == 3 {
            break
        }
        
        // Compute closest point.
        let p = simplex.getClosestPoint()
        distanceSqr2 = p.lengthSquared()
        // Ensure progress
        if distanceSqr2 >= distanceSqr1 {
            //break
        }
        distanceSqr1 = distanceSqr2
        
        // Get search direction.
        let d = simplex.getSearchDirection()
        
        // Ensure the search direction is numerically fit.
        if d.lengthSquared() < b2_epsilon * b2_epsilon {
            // The origin is probably contained by a line segment
            // or triangle. Thus the shapes are overlapped.
            
            // We can't return zero here even though there may be overlap.
            // In case the simplex is a point, segment, or triangle it is difficult
            // to determine if the origin is contained in the CSO or very close to it.
            break
        }
        
        // Compute a tentative new simplex vertex using support points.
        let vertex = simplex.m_v[simplex.m_count]
        vertex.indexA = proxyA.getSupport(b2MulT(transformA.q, -d))
        vertex.wA = b2Mul(transformA, proxyA.getVertex(vertex.indexA))
        //    var wBLocal: b2Vec2
        vertex.indexB = proxyB.getSupport(b2MulT(transformB.q, d))
        vertex.wB = b2Mul(transformB, proxyB.getVertex(vertex.indexB))
        vertex.w = vertex.wB - vertex.wA
        
        // Iteration count is equated to the number of support point calls.
        iter += 1
        b2_gjkIters += 1
        
        // Check for duplicate support points. This is the main termination criteria.
        var duplicate = false
        for i in 0 ..< saveCount {
            if vertex.indexA == saveA[i] && vertex.indexB == saveB[i] {
                duplicate = true
                break
            }
        }
        
        // If we found a duplicate support point we must exit to avoid cycling.
        if duplicate {
            break
        }
        
        // New vertex is ok and needed.
        simplex.m_count += 1
    }
    
    b2_gjkMaxIters = max(b2_gjkMaxIters, iter)
    
    // Prepare output.
    (output.pointA, output.pointB) = simplex.getWitnessPoints()
    output.distance = b2Distance(output.pointA, output.pointB)
    output.iterations = iter
    
    // Cache the simplex.
    simplex.writeCache(&cache)
    
    // Apply radii if requested.
    if input.useRadii {
        let rA = proxyA.m_radius
        let rB = proxyB.m_radius
        
        if output.distance > rA + rB && output.distance > b2_epsilon {
            // Shapes are still no overlapped.
            // Move the witness points to the outer surface.
            output.distance -= rA + rB
            var normal = output.pointB - output.pointA
            normal.normalize()
            output.pointA += rA * normal
            output.pointB -= rB * normal
        }
        else {
            // Shapes are overlapped when radii are considered.
            // Move the witness points to the middle.
            let p = 0.5 * (output.pointA + output.pointB)
            output.pointA = p
            output.pointB = p
            output.distance = 0.0
        }
    }
    return
}

// GJK using Voronoi regions (Christer Ericson) and Barycentric coordinates.
public var b2_gjkCalls = 0, b2_gjkIters = 0, b2_gjkMaxIters = 0
