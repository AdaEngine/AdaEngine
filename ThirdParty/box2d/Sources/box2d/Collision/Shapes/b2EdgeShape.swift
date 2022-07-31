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


/// A line segment (edge) shape. These can be connected in chains or loops
/// to other edge shapes. The connectivity information is used to ensure
/// correct contact normals.
open class b2EdgeShape : b2Shape {
  public override init() {
    m_vertex0 = b2Vec2(0.0, 0.0)
    m_vertex3 = b2Vec2(0.0, 0.0)
    m_hasVertex0 = false
    m_hasVertex3 = false
    super.init()
    m_type = b2ShapeType.edge
    m_radius = b2_polygonRadius
  }
  
  /// Set this as an isolated edge.
  open func set(vertex1 v1: b2Vec2, vertex2 v2: b2Vec2) {
    m_vertex1 = v1
    m_vertex2 = v2
    m_hasVertex0 = false
    m_hasVertex3 = false
  }
  
  /// Implement b2Shape.
  open override func clone() -> b2Shape {
    let clone = b2EdgeShape()
    clone.m_radius = m_radius
    clone.m_vertices = m_vertices.clone()
    clone.m_vertex0 = m_vertex0
    clone.m_vertex3 = m_vertex3
    clone.m_hasVertex0 = m_hasVertex0
    clone.m_hasVertex3 = m_hasVertex3
    return clone
  }
  
  /// @see b2Shape::GetChildCount
  open override var childCount: Int {
    return 1
  }
  
  /// @see b2Shape::TestPoint
  open override func testPoint(transform: b2Transform, point: b2Vec2) -> Bool {
    return false
  }
  
  // p = p1 + t * d
  // v = v1 + s * e
  // p1 + t * d = v1 + s * e
  // s * e - t * d = p1 - v1
  open override func rayCast(_ output: inout b2RayCastOutput, input: b2RayCastInput, transform xf: b2Transform, childIndex: Int) -> Bool {
    // Put the ray into the edge's frame of reference.
    let p1 = b2MulT(xf.q, input.p1 - xf.p)
    let p2 = b2MulT(xf.q, input.p2 - xf.p)
    let d = p2 - p1
    
    let v1 = m_vertex1
    let v2 = m_vertex2
    let e = v2 - v1
    var normal = b2Vec2(e.y, -e.x)
    normal.normalize()
    
    // q = p1 + t * d
    // dot(normal, q - v1) = 0
    // dot(normal, p1 - v1) + t * dot(normal, d) = 0
    let numerator = b2Dot(normal, v1 - p1)
    let denominator = b2Dot(normal, d)
    
    if denominator == 0.0 {
      return false
    }
    
    let t = numerator / denominator
    if t < 0.0 || input.maxFraction < t {
      return false
    }
    
    let q = p1 + t * d
    
    // q = v1 + s * r
    // s = dot(q - v1, r) / dot(r, r)
    let r = v2 - v1
    let rr = b2Dot(r, r)
    if rr == 0.0 {
      return false
    }
    
    let s = b2Dot(q - v1, r) / rr
    if s < 0.0 || 1.0 < s {
      return false
    }
    
    output.fraction = t
    if numerator > 0.0 {
      output.normal = -b2Mul(xf.q, normal)
    }
    else {
      output.normal = b2Mul(xf.q, normal)
    }
    return true
  }
  
  /// @see b2Shape::ComputeAABB
  open override func computeAABB(_ aabb: inout b2AABB, transform: b2Transform, childIndex: Int) {
    let v1 = b2Mul(transform, m_vertex1)
    let v2 = b2Mul(transform, m_vertex2)
    
    let lower = b2Min(v1, v2)
    let upper = b2Max(v1, v2)
    
    let r = b2Vec2(m_radius, m_radius)
    aabb.lowerBound = lower - r
    aabb.upperBound = upper + r
  }
  
  /// @see b2Shape::ComputeMass
  open override func computeMass(density: b2Float) -> b2MassData {
    var massData = b2MassData()
    massData.mass = 0.0
    massData.center = 0.5 * (m_vertex1 + m_vertex2)
    massData.I = 0.0
    return massData
  }
  
  open var vertex1 : b2Vec2 {
    get { return m_vertices[0] }
    set { m_vertices[0] = newValue }
  }

  open var vertex2 : b2Vec2 {
    get { return m_vertices[1] }
    set { m_vertices[1] = newValue }
  }
  
  open var vertex0: b2Vec2 {
    get { return m_vertex0 }
    set { m_vertex0 = newValue }
  }

  open var vertex3: b2Vec2 {
    get { return m_vertex3 }
    set { m_vertex3 = newValue }
  }

  open var hasVertex0: Bool {
    get { return m_hasVertex0 }
    set { m_hasVertex0 = newValue }
  }

  open var hasVertex3: Bool {
    get { return m_hasVertex3 }
    set { m_hasVertex3 = newValue }
  }

  // MARK: private variables
  
  /// These are the edge vertices
  var m_vertices = b2Array<b2Vec2>(count: 2, repeatedValue: b2Vec2())
  var m_vertex1 : b2Vec2 {
    get { return m_vertices[0] }
    set { m_vertices[0] = newValue }
  }
  var m_vertex2 : b2Vec2 {
    get { return m_vertices[1] }
    set { m_vertices[1] = newValue }
  }
  
  /// Optional adjacent vertices. These are used for smooth collision.
  var m_vertex0 : b2Vec2
  var m_vertex3 : b2Vec2
  var m_hasVertex0 : Bool
  var m_hasVertex3 : Bool
}

