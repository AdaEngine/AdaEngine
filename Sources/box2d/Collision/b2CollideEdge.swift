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

// Compute contact points for edge versus circle.
// This accounts for edge connectivity.
public func b2CollideEdgeAndCircle(
    manifold: inout b2Manifold,
    edgeA: b2EdgeShape,
    transformA xfA: b2Transform,
    circleB: b2CircleShape,
    transformB xfB: b2Transform)
{
    manifold.points.removeAll(keepingCapacity: true)
    
    // Compute circle in frame of edge
    let Q = b2MulT(xfA, b2Mul(xfB, circleB.m_p))
    
    let A = edgeA.m_vertex1
    let B = edgeA.m_vertex2
    let e = B - A
    
    // Barycentric coordinates
    let u = b2Dot(e, B - Q)
    let v = b2Dot(e, Q - A)
    
    let radius = edgeA.m_radius + circleB.m_radius
    
    var cf = b2ContactFeature()
    cf.indexB = 0
    cf.typeB = b2ContactFeatureType.vertex
    
    // Region A
    if v <= 0.0 {
        let P = A
        let d = Q - P
        let dd = b2Dot(d, d)
        if dd > radius * radius {
            return
        }
        
        // Is there an edge connected to A?
        if edgeA.m_hasVertex0 {
            let A1 = edgeA.m_vertex0
            let B1 = A
            let e1 = B1 - A1
            let u1 = b2Dot(e1, B1 - Q)
            
            // Is the circle in Region AB of the previous edge?
            if u1 > 0.0 {
                return
            }
        }
        
        cf.indexA = 0
        cf.typeA = b2ContactFeatureType.vertex
        manifold.type = b2ManifoldType.circles
        manifold.localNormal.setZero()
        manifold.localPoint = P
        let cp = b2ManifoldPoint()
        cp.id.setZero()
        cp.id = cf
        cp.localPoint = circleB.m_p
        manifold.points.append(cp)
        return
    }
    
    // Region B
    if u <= 0.0 {
        let P = B
        let d = Q - P
        let dd = b2Dot(d, d)
        if dd > radius * radius {
            return
        }
        
        // Is there an edge connected to B?
        if edgeA.m_hasVertex3 {
            let B2 = edgeA.m_vertex3
            let A2 = B
            let e2 = B2 - A2
            let v2 = b2Dot(e2, Q - A2)
            
            // Is the circle in Region AB of the next edge?
            if v2 > 0.0 {
                return
            }
        }
        
        cf.indexA = 1
        cf.typeA = b2ContactFeatureType.vertex
        manifold.type = b2ManifoldType.circles
        manifold.localNormal.setZero()
        manifold.localPoint = P
        let cp = b2ManifoldPoint()
        cp.id.setZero()
        cp.id = cf
        cp.localPoint = circleB.m_p
        manifold.points.append(cp)
        return
    }
    
    // Region AB
    let den = b2Dot(e, e)
    assert(den > 0.0)
    let P = (1.0 / den) * (u * A + v * B)
    let d = Q - P
    let dd = b2Dot(d, d)
    if dd > radius * radius {
        return
    }
    
    var n = b2Vec2(-e.y, e.x)
    if b2Dot(n, Q - A) < 0.0 {
        n.set(-n.x, -n.y)
    }
    n.normalize()
    
    cf.indexA = 0
    cf.typeA = b2ContactFeatureType.face
    manifold.type = b2ManifoldType.faceA
    manifold.localNormal = n
    manifold.localPoint = A
    let cp = b2ManifoldPoint()
    cp.id.setZero()
    cp.id = cf
    cp.localPoint = circleB.m_p
    manifold.points.append(cp)
    return
}

enum b2EPAxisType : CustomStringConvertible {
    case unknown
    case edgeA
    case edgeB
    var description: String {
        switch self {
        case .unknown: return "unknown"
        case .edgeA: return "edgeA"
        case .edgeB: return "edgeB"
        }
    }
}

// This structure is used to keep track of the best separating axis.
struct b2EPAxis : CustomStringConvertible {
    var type = b2EPAxisType.unknown
    var index = 0
    var separation: b2Float = 0
    var description: String {
        return "b2EPAxis[type=\(type), index=\(index), separation=\(separation)]"
    }
}

// This holds polygon B expressed in frame A.
struct b2TempPolygon {
    var vertices = [b2Vec2](repeating: b2Vec2(), count: b2_maxPolygonVertices)
    var normals = [b2Vec2](repeating: b2Vec2(), count: b2_maxPolygonVertices)
    var count = 0
}

// Reference face used for clipping
struct b2ReferenceFace {
    var i1 = 0, i2 = 0
    
    var v1 = b2Vec2(), v2 = b2Vec2()
    
    var normal = b2Vec2()
    
    var sideNormal1 = b2Vec2()
    var sideOffset1: b2Float = 0
    
    var sideNormal2 = b2Vec2()
    var sideOffset2: b2Float = 0
}

// This class collides and edge and a polygon, taking into account edge adjacency.
class b2EPCollider {
    // Algorithm:
    // 1. Classify v1 and v2
    // 2. Classify polygon centroid as front or back
    // 3. Flip normal if necessary
    // 4. Initialize normal range to [-pi, pi] about face normal
    // 5. Adjust normal range according to adjacent edges
    // 6. Visit each separating axes, only accept axes within the range
    // 7. Return if _any_ axis indicates separation
    // 8. Clip
    func Collide(_ edgeA: b2EdgeShape, _ xfA: b2Transform, _ polygonB: b2PolygonShape, _ xfB: b2Transform) -> b2Manifold {
        let manifold = b2Manifold()
        m_xf = b2MulT(xfA, xfB)
        
        m_centroidB = b2Mul(m_xf, polygonB.m_centroid)
        
        m_v0 = edgeA.m_vertex0
        m_v1 = edgeA.m_vertex1
        m_v2 = edgeA.m_vertex2
        m_v3 = edgeA.m_vertex3
        
        let hasVertex0 = edgeA.m_hasVertex0
        let hasVertex3 = edgeA.m_hasVertex3
        
        var edge1 = m_v2 - m_v1
        edge1.normalize()
        m_normal1.set(edge1.y, -edge1.x)
        let offset1 = b2Dot(m_normal1, m_centroidB - m_v1)
        var offset0: b2Float = 0.0, offset2: b2Float = 0.0
        var convex1 = false, convex2 = false
        
        // Is there a preceding edge?
        if hasVertex0 {
            var edge0 = m_v1 - m_v0
            edge0.normalize()
            m_normal0.set(edge0.y, -edge0.x)
            convex1 = b2Cross(edge0, edge1) >= 0.0
            offset0 = b2Dot(m_normal0, m_centroidB - m_v0)
        }
        
        // Is there a following edge?
        if hasVertex3 {
            var edge2 = m_v3 - m_v2
            edge2.normalize()
            m_normal2.set(edge2.y, -edge2.x)
            convex2 = b2Cross(edge1, edge2) > 0.0
            offset2 = b2Dot(m_normal2, m_centroidB - m_v2)
        }
        
        // Determine front or back collision. Determine collision normal limits.
        if hasVertex0 && hasVertex3 {
            if convex1 && convex2 {
                m_front = offset0 >= 0.0 || offset1 >= 0.0 || offset2 >= 0.0
                if m_front {
                    m_normal = m_normal1
                    m_lowerLimit = m_normal0
                    m_upperLimit = m_normal2
                }
                else {
                    m_normal = -m_normal1
                    m_lowerLimit = -m_normal1
                    m_upperLimit = -m_normal1
                }
            }
            else if convex1 {
                m_front = offset0 >= 0.0 || (offset1 >= 0.0 && offset2 >= 0.0)
                if m_front {
                    m_normal = m_normal1
                    m_lowerLimit = m_normal0
                    m_upperLimit = m_normal1
                }
                else {
                    m_normal = -m_normal1
                    m_lowerLimit = -m_normal2
                    m_upperLimit = -m_normal1
                }
            }
            else if convex2 {
                m_front = offset2 >= 0.0 || (offset0 >= 0.0 && offset1 >= 0.0)
                if m_front {
                    m_normal = m_normal1
                    m_lowerLimit = m_normal1
                    m_upperLimit = m_normal2
                }
                else {
                    m_normal = -m_normal1
                    m_lowerLimit = -m_normal1
                    m_upperLimit = -m_normal0
                }
            }
            else {
                m_front = offset0 >= 0.0 && offset1 >= 0.0 && offset2 >= 0.0
                if m_front {
                    m_normal = m_normal1
                    m_lowerLimit = m_normal1
                    m_upperLimit = m_normal1
                }
                else {
                    m_normal = -m_normal1
                    m_lowerLimit = -m_normal2
                    m_upperLimit = -m_normal0
                }
            }
        }
        else if hasVertex0 {
            if convex1 {
                m_front = offset0 >= 0.0 || offset1 >= 0.0
                if m_front {
                    m_normal = m_normal1
                    m_lowerLimit = m_normal0
                    m_upperLimit = -m_normal1
                }
                else {
                    m_normal = -m_normal1
                    m_lowerLimit = m_normal1
                    m_upperLimit = -m_normal1
                }
            }
            else {
                m_front = offset0 >= 0.0 && offset1 >= 0.0
                if m_front {
                    m_normal = m_normal1
                    m_lowerLimit = m_normal1
                    m_upperLimit = -m_normal1
                }
                else {
                    m_normal = -m_normal1
                    m_lowerLimit = m_normal1
                    m_upperLimit = -m_normal0
                }
            }
        }
        else if hasVertex3 {
            if convex2 {
                m_front = offset1 >= 0.0 || offset2 >= 0.0
                if m_front {
                    m_normal = m_normal1
                    m_lowerLimit = -m_normal1
                    m_upperLimit = m_normal2
                }
                else {
                    m_normal = -m_normal1
                    m_lowerLimit = -m_normal1
                    m_upperLimit = m_normal1
                }
            }
            else {
                m_front = offset1 >= 0.0 && offset2 >= 0.0
                if m_front {
                    m_normal = m_normal1
                    m_lowerLimit = -m_normal1
                    m_upperLimit = m_normal1
                }
                else {
                    m_normal = -m_normal1
                    m_lowerLimit = -m_normal2
                    m_upperLimit = m_normal1
                }
            }
        }
        else {
            m_front = offset1 >= 0.0
            if m_front {
                m_normal = m_normal1
                m_lowerLimit = -m_normal1
                m_upperLimit = -m_normal1
            }
            else {
                m_normal = -m_normal1
                m_lowerLimit = m_normal1
                m_upperLimit = m_normal1
            }
        }
        
        // Get polygonB in frameA
        m_polygonB.count = polygonB.m_count
        for i in 0 ..< polygonB.m_count {
            m_polygonB.vertices[i] = b2Mul(m_xf, polygonB.m_vertices[i])
            m_polygonB.normals[i] = b2Mul(m_xf.q, polygonB.m_normals[i])
        }
        
        m_radius = 2.0 * b2_polygonRadius
        
        //manifold.pointCount = 0
        manifold.points.removeAll(keepingCapacity: true)
        
        let edgeAxis = ComputeEdgeSeparation()
        
        // If no valid normal can be found than this edge should not collide.
        if edgeAxis.type == b2EPAxisType.unknown {
            return manifold
        }
        
        if edgeAxis.separation > m_radius {
            return manifold
        }
        
        let polygonAxis = ComputePolygonSeparation()
        if polygonAxis.type != b2EPAxisType.unknown && polygonAxis.separation > m_radius {
            return manifold
        }
        
        // Use hysteresis for jitter reduction.
        let k_relativeTol:b2Float = 0.98
        let k_absoluteTol:b2Float = 0.001
        
        var primaryAxis: b2EPAxis
        if polygonAxis.type == b2EPAxisType.unknown {
            primaryAxis = edgeAxis
        }
        else if polygonAxis.separation > k_relativeTol * edgeAxis.separation + k_absoluteTol {
            primaryAxis = polygonAxis
        }
        else {
            primaryAxis = edgeAxis
        }
        
        var ie = [b2ClipVertex](repeating: b2ClipVertex(), count: 2)
        var rf = b2ReferenceFace()
        if primaryAxis.type == b2EPAxisType.edgeA {
            manifold.type = b2ManifoldType.faceA
            
            // Search for the polygon normal that is most anti-parallel to the edge normal.
            var bestIndex = 0
            var bestValue = b2Dot(m_normal, m_polygonB.normals[0])
            for i in 1 ..< m_polygonB.count {
                let value = b2Dot(m_normal, m_polygonB.normals[i])
                if value < bestValue {
                    bestValue = value
                    bestIndex = i
                }
            }
            
            let i1 = bestIndex
            let i2 = i1 + 1 < m_polygonB.count ? i1 + 1 : 0
            
            ie[0].v = m_polygonB.vertices[i1]
            ie[0].id.indexA = 0
            ie[0].id.indexB = UInt8(i1)
            ie[0].id.typeA = b2ContactFeatureType.face
            ie[0].id.typeB = b2ContactFeatureType.vertex
            
            ie[1].v = m_polygonB.vertices[i2]
            ie[1].id.indexA = 0
            ie[1].id.indexB = UInt8(i2)
            ie[1].id.typeA = b2ContactFeatureType.face
            ie[1].id.typeB = b2ContactFeatureType.vertex
            
            if m_front {
                rf.i1 = 0
                rf.i2 = 1
                rf.v1 = m_v1
                rf.v2 = m_v2
                rf.normal = m_normal1
            }
            else {
                rf.i1 = 1
                rf.i2 = 0
                rf.v1 = m_v2
                rf.v2 = m_v1
                rf.normal = -m_normal1
            }
        }
        else {
            manifold.type = b2ManifoldType.faceB
            
            ie[0].v = m_v1
            ie[0].id.indexA = 0
            ie[0].id.indexB = UInt8(primaryAxis.index)
            ie[0].id.typeA = b2ContactFeatureType.vertex
            ie[0].id.typeB = b2ContactFeatureType.face
            
            ie[1].v = m_v2
            ie[1].id.indexA = 0
            ie[1].id.indexB = UInt8(primaryAxis.index)
            ie[1].id.typeA = b2ContactFeatureType.vertex
            ie[1].id.typeB = b2ContactFeatureType.face
            
            rf.i1 = primaryAxis.index
            rf.i2 = rf.i1 + 1 < m_polygonB.count ? rf.i1 + 1 : 0
            rf.v1 = m_polygonB.vertices[rf.i1]
            rf.v2 = m_polygonB.vertices[rf.i2]
            rf.normal = m_polygonB.normals[rf.i1]
        }
        
        rf.sideNormal1.set(rf.normal.y, -rf.normal.x)
        rf.sideNormal2 = -rf.sideNormal1
        rf.sideOffset1 = b2Dot(rf.sideNormal1, rf.v1)
        rf.sideOffset2 = b2Dot(rf.sideNormal2, rf.v2)
        
        // Clip incident edge against extruded edge1 side edges.
        // Clip to box side 1
        let clipPoints1 = b2ClipSegmentToLine(inputVertices: ie, normal: rf.sideNormal1, offset: rf.sideOffset1, vertexIndexA: rf.i1)
        
        if clipPoints1.count < b2_maxManifoldPoints {
            return manifold
        }
        
        // Clip to negative box side 1
        let clipPoints2 = b2ClipSegmentToLine(inputVertices: clipPoints1, normal: rf.sideNormal2, offset: rf.sideOffset2, vertexIndexA: rf.i2)
        
        if clipPoints2.count < b2_maxManifoldPoints {
            return manifold
        }
        
        // Now clipPoints2 contains the clipped points.
        if primaryAxis.type == b2EPAxisType.edgeA {
            manifold.localNormal = rf.normal
            manifold.localPoint = rf.v1
        }
        else {
            manifold.localNormal = polygonB.m_normals[rf.i1]
            manifold.localPoint = polygonB.m_vertices[rf.i1]
        }
        
        var pointCount = 0
        for i in 0 ..< b2_maxManifoldPoints {
            let separation = b2Dot(rf.normal, clipPoints2[i].v - rf.v1)
            
            if separation <= m_radius {
                let cp = b2ManifoldPoint() //manifold.points[pointCount]
                
                if primaryAxis.type == b2EPAxisType.edgeA {
                    cp.localPoint = b2MulT(m_xf, clipPoints2[i].v)
                    cp.id = clipPoints2[i].id
                }
                else {
                    cp.localPoint = clipPoints2[i].v
                    cp.id.typeA = clipPoints2[i].id.typeB
                    cp.id.typeB = clipPoints2[i].id.typeA
                    cp.id.indexA = clipPoints2[i].id.indexB
                    cp.id.indexB = clipPoints2[i].id.indexA
                }
                manifold.points.append(cp)
                pointCount += 1
            }
        }
        return manifold
    }
    
    func ComputeEdgeSeparation() -> b2EPAxis {
        var axis = b2EPAxis()
        axis.type = b2EPAxisType.edgeA
        axis.index = m_front ? 0 : 1
        axis.separation = Float.greatestFiniteMagnitude
        
        for i in 0 ..< m_polygonB.count {
            let s = b2Dot(m_normal, m_polygonB.vertices[i] - m_v1)
            if s < axis.separation {
                axis.separation = s
            }
        }
        
        return axis
    }
    
    func ComputePolygonSeparation() -> b2EPAxis {
        var axis = b2EPAxis()
        axis.type = b2EPAxisType.unknown
        axis.index = -1
        axis.separation = -Float.greatestFiniteMagnitude
        
        let perp = b2Vec2(-m_normal.y, m_normal.x)
        
        for i in 0 ..< m_polygonB.count {
            let n = -m_polygonB.normals[i]
            
            let s1 = b2Dot(n, m_polygonB.vertices[i] - m_v1)
            let s2 = b2Dot(n, m_polygonB.vertices[i] - m_v2)
            let s = min(s1, s2)
            
            if s > m_radius {
                // No collision
                axis.type = b2EPAxisType.edgeB
                axis.index = i
                axis.separation = s
                return axis
            }
            
            // Adjacency
            if b2Dot(n, perp) >= 0.0 {
                if b2Dot(n - m_upperLimit, m_normal) < -b2_angularSlop {
                    continue
                }
            }
            else {
                if b2Dot(n - m_lowerLimit, m_normal) < -b2_angularSlop {
                    continue
                }
            }
            
            if s > axis.separation {
                axis.type = b2EPAxisType.edgeB
                axis.index = i
                axis.separation = s
            }
        }
        
        return axis
    }
    
    enum VertexType : CustomStringConvertible {
        case isolated
        case concave
        case convex
        var description: String {
            switch self {
            case .isolated: return "isolated"
            case .concave: return "concave"
            case .convex: return "convex"
            }
        }
    }
    
    var m_polygonB = b2TempPolygon()
    
    var m_xf = b2Transform()
    var m_centroidB = b2Vec2()
    var m_v0 = b2Vec2(), m_v1 = b2Vec2(), m_v2 = b2Vec2(), m_v3 = b2Vec2()
    var m_normal0 = b2Vec2(), m_normal1 = b2Vec2(), m_normal2 = b2Vec2()
    var m_normal = b2Vec2()
    var m_type1 = VertexType.isolated, m_type2 = VertexType.isolated
    var m_lowerLimit = b2Vec2(), m_upperLimit = b2Vec2()
    var m_radius: b2Float = 0
    var m_front = false
}

/// Compute the collision manifold between an edge and a circle.
public func b2CollideEdgeAndPolygon(
    manifold: inout b2Manifold,
    edgeA: b2EdgeShape,
    transformA xfA: b2Transform,
    polygonB: b2PolygonShape,
    transformB xfB: b2Transform
) {
    let collider = b2EPCollider()
    manifold = collider.Collide(edgeA, xfA, polygonB, xfB)
}

