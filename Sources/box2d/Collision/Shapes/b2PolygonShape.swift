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

open class b2PolygonShape : b2Shape {
  public override init() {
    m_centroid = b2Vec2(0.0, 0.0)
    super.init()
    m_type = b2ShapeType.polygon
    m_radius = b2_polygonRadius
  }
  
  /// Implement b2Shape.
  open override func clone() -> b2Shape {
    let clone = b2PolygonShape()
    clone.m_centroid = m_centroid
    clone.m_vertices = m_vertices.clone()
    clone.m_normals = m_normals.clone()
    clone.m_radius = m_radius
    return clone
  }
  
  /// @see b2Shape::GetChildCount
  open override var childCount: Int {
    return 1
  }
  
  /// Create a convex hull from the given array of local points.
  /// The count must be in the range [3, b2_maxPolygonVertices].
  /// @warning the points may be re-ordered, even if they form a convex polygon
  /// @warning collinear points are handled but not removed. Collinear points
  /// may lead to poor stacking behavior.
  open func set(vertices: [b2Vec2]) {
    assert(3 <= vertices.count && vertices.count <= b2_maxPolygonVertices)
    if vertices.count < 3 {
      setAsBox(halfWidth: 1.0, halfHeight: 1.0)
      return
    }
    
    var n = min(vertices.count, b2_maxPolygonVertices)
    
    // Perform welding and copy vertices into local buffer.
    let ps = b2Array<b2Vec2>()
    //int32 tempCount = 0
    for i in 0 ..< n {
      let v = vertices[i]
      
      var unique = true
      for j in 0 ..< ps.count {
        if b2DistanceSquared(v, ps[j]) < ((0.5 * b2_linearSlop) * (0.5 * b2_linearSlop)) {
          unique = false
          break
        }
      }
      
      if unique {
        ps.append(v)
      }
    }
    
    n = ps.count
    if n < 3 {
      // Polygon is degenerate.
      assert(false)
      setAsBox(halfWidth: 1.0, halfHeight: 1.0)
      return
    }
    
    // Create the convex hull using the Gift wrapping algorithm
    // http://en.wikipedia.org/wiki/Gift_wrapping_algorithm
    
    // Find the right most point on the hull
    var i0 = 0
    var x0 = ps[0].x
    for i in 1 ..< n {
      let x = ps[i].x
      if x > x0 || (x == x0 && ps[i].y < ps[i0].y) {
        i0 = i
        x0 = x
      }
    }
    
    var hull = [Int]()
    var ih = i0
    
    while true {
      hull.append(ih)
      
      var ie = 0
      for j in 1 ..< n {
        if ie == ih {
          ie = j
          continue
        }
        
        let r = ps[ie] - ps[hull.last!]
        let v = ps[j] - ps[hull.last!]
        let c = b2Cross(r, v)
        if c < 0.0 {
          ie = j
        }
        
        // Collinearity check
        if c == 0.0 && v.lengthSquared() > r.lengthSquared() {
          ie = j
        }
      }
      
      ih = ie
      
      if ie == i0 {
        break
      }
    }
    
    let m = hull.count
    
    // Copy vertices.
    m_vertices.removeAll()
    for i in 0 ..< m {
      //m_vertices[i] = ps[hull[i]]
      m_vertices.append(ps[hull[i]])
    }
    
    // Compute normals. Ensure the edges have non-zero length.
    m_normals.removeAll()
    for i in 0 ..< m {
      let i1 = i
      let i2 = i + 1 < m ? i + 1 : 0
      let edge = m_vertices[i2] - m_vertices[i1]
      assert(edge.lengthSquared() > b2_epsilon * b2_epsilon)
      m_normals.append(b2Cross(edge, 1.0))
      m_normals[i].normalize()
    }
    
    // Compute the polygon centroid.
    m_centroid = ComputeCentroid(m_vertices)
  }
  
  /**
  Build vertices to represent an axis-aligned box centered on the local origin.
  
  - parameter halfWidth: the half-width.
  - parameter halfHeight: the half-height.
  */
  open func setAsBox(halfWidth hx: b2Float, halfHeight hy: b2Float) {
    m_vertices.removeAll()
    m_vertices.append(b2Vec2(-hx, -hy))
    m_vertices.append(b2Vec2( hx, -hy))
    m_vertices.append(b2Vec2( hx,  hy))
    m_vertices.append(b2Vec2(-hx,  hy))
    m_normals.removeAll()
    m_normals.append(b2Vec2( 0.0, -1.0))
    m_normals.append(b2Vec2( 1.0,  0.0))
    m_normals.append(b2Vec2( 0.0,  1.0))
    m_normals.append(b2Vec2(-1.0,  0.0))
    m_centroid.setZero()
  }

  /**
  Build vertices to represent an oriented box.
  
  - parameter hx: the half-width.
  - parameter hy: the half-height.
  - parameter center: the center of the box in local coordinates.
  - parameter angle: the rotation of the box in local coordinates.
  */
  open func setAsBox(halfWidth hx: b2Float, halfHeight hy: b2Float, center: b2Vec2, angle: b2Float) {
    m_vertices.removeAll()
    m_vertices.append(b2Vec2(-hx, -hy))
    m_vertices.append(b2Vec2( hx, -hy))
    m_vertices.append(b2Vec2( hx,  hy))
    m_vertices.append(b2Vec2(-hx,  hy))
    m_normals.removeAll()
    m_normals.append(b2Vec2( 0.0, -1.0))
    m_normals.append(b2Vec2( 1.0,  0.0))
    m_normals.append(b2Vec2( 0.0,  1.0))
    m_normals.append(b2Vec2(-1.0,  0.0))
    m_centroid = center
    
    var xf = b2Transform()
    xf.p = center
    xf.q.set(angle)
    
    // Transform vertices and normals.
    for i in 0 ..< m_count {
      m_vertices[i] = b2Mul(xf, m_vertices[i])
      m_normals[i] = b2Mul(xf.q, m_normals[i])
    }
  }
  
  /// @see b2Shape::TestPoint
  open override func testPoint(transform: b2Transform, point p: b2Vec2) -> Bool {
    let pLocal = b2MulT(transform.q, p - transform.p)
    
    for i in 0 ..< m_count {
      let dot = b2Dot(m_normals[i], pLocal - m_vertices[i])
      if dot > 0.0 {
        return false
      }
    }
    
    return true
  }
  
  /// Implement b2Shape.
  open override func rayCast(_ output: inout b2RayCastOutput, input: b2RayCastInput, transform xf: b2Transform, childIndex: Int) -> Bool {
    // Put the ray into the polygon's frame of reference.
    let p1 = b2MulT(xf.q, input.p1 - xf.p)
    let p2 = b2MulT(xf.q, input.p2 - xf.p)
    let d = p2 - p1
    
    var lower: b2Float = 0.0, upper = input.maxFraction
    
    var index = -1
    
    for i in 0 ..< m_count {
      // p = p1 + a * d
      // dot(normal, p - v) = 0
      // dot(normal, p1 - v) + a * dot(normal, d) = 0
      let numerator = b2Dot(m_normals[i], m_vertices[i] - p1)
      let denominator = b2Dot(m_normals[i], d)
      
      if denominator == 0.0 {
        if numerator < 0.0 {
          return false
        }
      }
      else {
        // Note: we want this predicate without division:
        // lower < numerator / denominator, where denominator < 0
        // Since denominator < 0, we have to flip the inequality:
        // lower < numerator / denominator <==> denominator * lower > numerator.
        if denominator < 0.0 && numerator < lower * denominator {
          // Increase lower.
          // The segment enters this half-space.
          lower = numerator / denominator
          index = i
        }
        else if denominator > 0.0 && numerator < upper * denominator {
          // Decrease upper.
          // The segment exits this half-space.
          upper = numerator / denominator
        }
      }
      
      // The use of epsilon here causes the assert on lower to trip
      // in some cases. Apparently the use of epsilon was to make edge
      // shapes work, but now those are handled separately.
      //if (upper < lower - b2_epsilon)
      if upper < lower {
        return false
      }
    }
    
    assert(0.0 <= lower && lower <= input.maxFraction)
    
    if index >= 0 {
      output.fraction = lower
      output.normal = b2Mul(xf.q, m_normals[index])
      return true
    }
    
    return false
  }
  
  /// @see b2Shape::ComputeAABB
  open override func computeAABB(_ aabb: inout b2AABB, transform: b2Transform, childIndex: Int) {
    var lower = b2Mul(transform, m_vertices[0])
    var upper = lower
    
    for i in 1 ..< m_count {
      let v = b2Mul(transform, m_vertices[i])
      lower = b2Min(lower, v)
      upper = b2Max(upper, v)
    }
    
    let r = b2Vec2(m_radius, m_radius)
    aabb.lowerBound = lower - r
    aabb.upperBound = upper + r
  }
  
  /// @see b2Shape::ComputeMass
  open override func computeMass(density: b2Float) -> b2MassData {
    // Polygon mass, centroid, and inertia.
    // Let rho be the polygon density in mass per unit area.
    // Then:
    // mass = rho * int(dA)
    // centroid.x = (1/mass) * rho * int(x * dA)
    // centroid.y = (1/mass) * rho * int(y * dA)
    // I = rho * int((x*x + y*y) * dA)
    //
    // We can compute these integrals by summing all the integrals
    // for each triangle of the polygon. To evaluate the integral
    // for a single triangle, we make a change of variables to
    // the (u,v) coordinates of the triangle:
    // x = x0 + e1x * u + e2x * v
    // y = y0 + e1y * u + e2y * v
    // where 0 <= u && 0 <= v && u + v <= 1.
    //
    // We integrate u from [0,1-v] and then v from [0,1].
    // We also need to use the Jacobian of the transformation:
    // D = cross(e1, e2)
    //
    // Simplification: triangle centroid = (1/3) * (p1 + p2 + p3)
    //
    // The rest of the derivation is handled by computer algebra.
    
    assert(m_vertices.count >= 3)
    
    var center = b2Vec2(0.0, 0.0)
    var area: b2Float = 0.0
    var I: b2Float = 0.0
    
    // s is the reference point for forming triangles.
    // It's location doesn't change the result (except for rounding error).
    var s = b2Vec2(0.0, 0.0)
    
    // This code would put the reference point inside the polygon.
    for i in 0 ..< m_count {
      s += m_vertices[i]
    }
    s *= b2Float(1.0) / b2Float(m_vertices.count)
    
    let k_inv3: b2Float = 1.0 / 3.0
    
    for i in 0 ..< m_count {
      // Triangle vertices.
      let e1 = m_vertices[i] - s
      let e2 = i + 1 < m_count ? m_vertices[i+1] - s : m_vertices[0] - s
      
      let D = b2Cross(e1, e2)
      
      let triangleArea = 0.5 * D
      area += triangleArea
      
      // Area weighted centroid
      center += triangleArea * k_inv3 * (e1 + e2)
      
      let ex1 = e1.x, ey1 = e1.y
      let ex2 = e2.x, ey2 = e2.y
      
      let intx2 = ex1*ex1 + ex2*ex1 + ex2*ex2
      let inty2 = ey1*ey1 + ey2*ey1 + ey2*ey2
      
      I += (0.25 * k_inv3 * D) * (intx2 + inty2)
    }
    
    // Total mass
    var massData = b2MassData()
    massData.mass = density * area
    
    // Center of mass
    assert(area > b2_epsilon)
    center *= 1.0 / area
    massData.center = center + s
    
    // Inertia tensor relative to the local origin (point s).
    massData.I = density * I
    
    // Shift to center of mass then to original body origin.
    massData.I += massData.mass * (b2Dot(massData.center, massData.center) - b2Dot(center, center))
    return massData
  }
  
  /// Get the vertex count.
  open var vertexCount: Int { return m_count }
  
  /// Get a vertex by index.
  open func vertex(_ index : Int) -> b2Vec2 {
    assert(0 <= index && index < m_vertices.count)
    return m_vertices[index]
  }
  
  /// Validate convexity. This is a very time consuming operation.
  /// @returns true if valid
  open func validate() -> Bool {
    for i in 0 ..< m_vertices.count {
    let i1 = i
    let i2 = i < m_vertices.count - 1 ? i1 + 1 : 0
    let p = m_vertices[i1]
    let e = m_vertices[i2] - p
    
    for j in 0 ..< m_count {
      if j == i1 || j == i2 {
      continue
      }
      
      let v = m_vertices[j] - p
      let c = b2Cross(e, v)
      if c < 0.0 {
        return false
      }
    }
    }
    
    return true
  }

  open var vertices: b2Array<b2Vec2> {
    return m_vertices
  }

  open var count: Int {
    return m_count
  }

  open override var description: String {
    var s = String()
    s += "b2PolygonShape["
    s += "m_centroid: \(m_centroid), "
    s += "m_vertices: \(m_vertices), "
    s += "m_normals: \(m_normals)]"
    return s
  }
  
  // MARK: private variables
  
  var m_centroid = b2Vec2()
  var m_vertices = b2Array<b2Vec2>()
  var m_normals = b2Array<b2Vec2>()
  var m_count: Int { return m_vertices.count }
}

private func ComputeCentroid(_ vs: b2Array<b2Vec2>) -> b2Vec2 {
  assert(vs.count >= 3)
  
  var c = b2Vec2(0.0, 0.0)
  var area: b2Float = 0.0
  
  // pRef is the reference point for forming triangles.
  // It's location doesn't change the result (except for rounding error).
  var pRef = b2Vec2(0.0, 0.0)
#if false
  // This code would put the reference point inside the polygon.
  for i in 0 ..< vs.count {
        pRef += vs[i]
  }
  pRef *= b2Float(1.0) / b2Float(vs.count)
#endif
  
  let inv3: b2Float = 1.0 / 3.0
  
  for i in 0 ..< vs.count {
    // Triangle vertices.
    let p1 = pRef
    let p2 = vs[i]
    let p3 = i + 1 < vs.count ? vs[i+1] : vs[0]
    
    let e1 = p2 - p1
    let e2 = p3 - p1
    
    let D = b2Cross(e1, e2)
    
    let triangleArea: b2Float = 0.5 * D
    area += triangleArea
    
    // Area weighted centroid
    c += triangleArea * inv3 * (p1 + p2 + p3)
  }
  
  // Centroid
  assert(area > b2_epsilon)
  c *= b2Float(1.0) / area
  return c
}

