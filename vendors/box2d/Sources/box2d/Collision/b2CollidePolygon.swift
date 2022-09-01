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

// Find the max separation between poly1 and poly2 using edge normals from poly1.
func b2FindMaxSeparation(_ poly1: b2PolygonShape, xf1: b2Transform,
                         poly2: b2PolygonShape, xf2: b2Transform) -> (edgeIndex: Int, maxSeparation: b2Float)
{
    let count1 = poly1.m_count
    let count2 = poly2.m_count
    let n1s = poly1.m_normals
    let v1s = poly1.m_vertices
    let v2s = poly2.m_vertices
    let xf = b2MulT(xf2, xf1)
    
    var bestIndex = 0
    var maxSeparation = -b2_maxFloat
    for i in 0 ..< count1 {
        // Get poly1 normal in frame2.
        let n = b2Mul(xf.q, n1s[i])
        let v1 = b2Mul(xf, v1s[i])
        
        // Find deepest point for normal i.
        var si = b2_maxFloat
        for j in 0 ..< count2 {
            let sij = b2Dot(n, v2s[j] - v1)
            if sij < si {
                si = sij
            }
        }
        
        if si > maxSeparation {
            maxSeparation = si
            bestIndex = i
        }
    }
    
    return (bestIndex, maxSeparation)
}

func b2FindIncidentEdge(_ poly1: b2PolygonShape, xf1: b2Transform, edge1: Int,
                        poly2: b2PolygonShape, xf2: b2Transform) -> [b2ClipVertex]
{
    let normals1 = poly1.m_normals
    
    let count2 = poly2.m_count
    let vertices2 = poly2.m_vertices
    let normals2 = poly2.m_normals
    
    assert(0 <= edge1 && edge1 < poly1.m_count)
    
    // Get the normal of the reference edge in poly2's frame.
    let normal1 = b2MulT(xf2.q, b2Mul(xf1.q, normals1[edge1]))
    
    // Find the incident edge on poly2.
    var index = 0
    var minDot = b2_maxFloat
    for i in 0 ..< count2 {
        let dot = b2Dot(normal1, normals2[i])
        if dot < minDot {
            minDot = dot
            index = i
        }
    }
    
    // Build the clip vertices for the incident edge.
    let i1 = index
    let i2 = i1 + 1 < count2 ? i1 + 1 : 0
    
    var c = [b2ClipVertex](repeating: b2ClipVertex(), count: 2)
    c[0].v = b2Mul(xf2, vertices2[i1])
    c[0].id.indexA = UInt8(edge1)
    c[0].id.indexB = UInt8(i1)
    c[0].id.typeA = b2ContactFeatureType.face
    c[0].id.typeB = b2ContactFeatureType.vertex
    
    c[1].v = b2Mul(xf2, vertices2[i2])
    c[1].id.indexA = UInt8(edge1)
    c[1].id.indexB = UInt8(i2)
    c[1].id.typeA = b2ContactFeatureType.face
    c[1].id.typeB = b2ContactFeatureType.vertex
    return c
}

/// Compute the collision manifold between two polygons.
// Find edge normal of max separation on A - return if separating axis is found
// Find edge normal of max separation on B - return if separation axis is found
// Choose reference edge as min(minA, minB)
// Find incident edge
// Clip
// The normal points from 1 to 2
public func b2CollidePolygons(
    manifold: inout b2Manifold,
    polygonA polyA: b2PolygonShape, transformA xfA: b2Transform,
    polygonB polyB: b2PolygonShape, transformB xfB: b2Transform)
{
    manifold.points.removeAll(keepingCapacity: true)
    let totalRadius = polyA.m_radius + polyB.m_radius
    
    let (edgeA, separationA) = b2FindMaxSeparation(polyA, xf1: xfA, poly2: polyB, xf2: xfB)
    if separationA > totalRadius {
        return
    }
    
    let (edgeB, separationB) = b2FindMaxSeparation(polyB, xf1: xfB, poly2: polyA, xf2: xfA)
    if separationB > totalRadius {
        return
    }
    
    var poly1: b2PolygonShape	// reference polygon
    var poly2: b2PolygonShape	// incident polygon
    var xf1: b2Transform, xf2: b2Transform
    var edge1: Int					// reference edge
    var flip: Bool
    let k_tol: b2Float = 0.1 * b2_linearSlop
    
    if separationB > separationA + k_tol {
        poly1 = polyB
        poly2 = polyA
        xf1 = xfB
        xf2 = xfA
        edge1 = edgeB
        manifold.type = b2ManifoldType.faceB
        flip = true
    }
    else {
        poly1 = polyA
        poly2 = polyB
        xf1 = xfA
        xf2 = xfB
        edge1 = edgeA
        manifold.type = b2ManifoldType.faceA
        flip = false
    }
    
    let incidentEdge = b2FindIncidentEdge(poly1, xf1: xf1, edge1: edge1, poly2: poly2, xf2: xf2)
    
    let count1 = poly1.m_count
    let vertices1 = poly1.m_vertices
    
    let iv1 = edge1
    let iv2 = edge1 + 1 < count1 ? edge1 + 1 : 0
    
    var v11 = vertices1[iv1]
    var v12 = vertices1[iv2]
    
    var localTangent = v12 - v11
    localTangent.normalize()
    
    let localNormal = b2Cross(localTangent, 1.0)
    let planePoint = 0.5 * (v11 + v12)
    
    let tangent = b2Mul(xf1.q, localTangent)
    let normal = b2Cross(tangent, 1.0)
    
    v11 = b2Mul(xf1, v11)
    v12 = b2Mul(xf1, v12)
    
    // Face offset.
    let frontOffset = b2Dot(normal, v11)
    
    // Side offsets, extended by polytope skin thickness.
    let sideOffset1 = -b2Dot(tangent, v11) + totalRadius
    let sideOffset2 = b2Dot(tangent, v12) + totalRadius
    
    // Clip incident edge against extruded edge1 side edges.
    // Clip to box side 1
    let clipPoints1 = b2ClipSegmentToLine(inputVertices: incidentEdge, normal: -tangent, offset: sideOffset1, vertexIndexA: iv1)
    
    if clipPoints1.count < 2 {
        return
    }
    
    // Clip to negative box side 1
    let clipPoints2 = b2ClipSegmentToLine(inputVertices: clipPoints1, normal: tangent, offset: sideOffset2, vertexIndexA: iv2)
    
    if clipPoints2.count < 2 {
        return
    }
    
    // Now clipPoints2 contains the clipped points.
    manifold.localNormal = localNormal
    manifold.localPoint = planePoint
    
    var pointCount = 0
    for i in 0 ..< b2_maxManifoldPoints {
        let separation = b2Dot(normal, clipPoints2[i].v) - frontOffset
        
        if separation <= totalRadius {
            let cp = b2ManifoldPoint() // manifold.points[pointCount]
            cp.localPoint = b2MulT(xf2, clipPoints2[i].v)
            cp.id = clipPoints2[i].id
            if flip {
                // Swap features
                let cf = cp.id
                cp.id.indexA = cf.indexB
                cp.id.indexB = cf.indexA
                cp.id.typeA = cf.typeB
                cp.id.typeB = cf.typeA
            }
            manifold.points.append(cp)
            pointCount += 1
        }
    }
    return
}
