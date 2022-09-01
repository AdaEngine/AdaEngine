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

/// Compute the collision manifold between two circles.
public func b2CollideCircles(
    manifold: inout b2Manifold,
    circleA: b2CircleShape, transformA xfA: b2Transform,
    circleB: b2CircleShape, transformB xfB: b2Transform)
{
    manifold.points.removeAll(keepingCapacity: true)
    
    let pA = b2Mul(xfA, circleA.m_p)
    let pB = b2Mul(xfB, circleB.m_p)
    
    let d = pB - pA
    let distSqr = b2Dot(d, d)
    let rA = circleA.m_radius
    let rB = circleB.m_radius
    let radius = rA + rB
    if distSqr > radius * radius {
        return
    }
    
    manifold.type = b2ManifoldType.circles
    manifold.localPoint = circleA.m_p
    manifold.localNormal.setZero()
    let cp = b2ManifoldPoint()
    cp.localPoint = circleB.m_p
    cp.id.setZero()
    manifold.points.append(cp)
}

/// Compute the collision manifold between a polygon and a circle.
public func b2CollidePolygonAndCircle(
    manifold: inout b2Manifold,
    polygonA: b2PolygonShape, transformA xfA: b2Transform,
    circleB: b2CircleShape, transformB xfB: b2Transform)
{
    manifold.points.removeAll(keepingCapacity: true)
    
    // Compute circle position in the frame of the polygon.
    let c = b2Mul(xfB, circleB.m_p)
    let cLocal = b2MulT(xfA, c)
    
    // Find the min separating edge.
    var normalIndex = 0
    var separation = -b2_maxFloat
    let radius = polygonA.m_radius + circleB.m_radius
    let vertexCount = polygonA.m_count
    let vertices = polygonA.m_vertices
    let normals = polygonA.m_normals
    
    for i in 0 ..< vertexCount {
        let s = b2Dot(normals[i], cLocal - vertices[i])
        
        if s > radius {
            // Early out.
            return
        }
        
        if s > separation {
            separation = s
            normalIndex = i
        }
    }
    
    // Vertices that subtend the incident face.
    let vertIndex1 = normalIndex
    let vertIndex2 = vertIndex1 + 1 < vertexCount ? vertIndex1 + 1 : 0
    let v1 = vertices[vertIndex1]
    let v2 = vertices[vertIndex2]
    
    // If the center is inside the polygon ...
    if separation < b2_epsilon {
        manifold.type = b2ManifoldType.faceA
        manifold.localNormal = normals[normalIndex]
        manifold.localPoint = 0.5 * (v1 + v2)
        let cp = b2ManifoldPoint()
        cp.localPoint = circleB.m_p
        cp.id.setZero()
        manifold.points.append(cp)
        return
    }
    
    // Compute barycentric coordinates
    let u1 = b2Dot(cLocal - v1, v2 - v1)
    let u2 = b2Dot(cLocal - v2, v1 - v2)
    if u1 <= 0.0 {
        if b2DistanceSquared(cLocal, v1) > radius * radius {
            return
        }
        
        manifold.type = b2ManifoldType.faceA
        manifold.localNormal = cLocal - v1
        manifold.localNormal.normalize()
        manifold.localPoint = v1
        let cp = b2ManifoldPoint()
        cp.localPoint = circleB.m_p
        cp.id.setZero()
        manifold.points.append(cp)
    }
    else if u2 <= 0.0 {
        if b2DistanceSquared(cLocal, v2) > radius * radius {
            return
        }
        
        manifold.type = b2ManifoldType.faceA
        manifold.localNormal = cLocal - v2
        manifold.localNormal.normalize()
        manifold.localPoint = v2
        let cp = b2ManifoldPoint()
        cp.localPoint = circleB.m_p
        cp.id.setZero()
        manifold.points.append(cp)
    }
    else {
        let faceCenter = 0.5 * (v1 + v2)
        let separation = b2Dot(cLocal - faceCenter, normals[vertIndex1])
        if separation > radius {
            return
        }
        
        manifold.type = b2ManifoldType.faceA
        manifold.localNormal = normals[vertIndex1]
        manifold.localPoint = faceCenter
        let cp = b2ManifoldPoint()
        cp.localPoint = circleB.m_p
        cp.id.setZero()
        manifold.points.append(cp)
    }
    return
}

