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

/// A circle shape.
open class b2CircleShape : b2Shape {
  public override init() {
    super.init()
    m_type = b2ShapeType.circle
    m_radius = 0.0
    m_p = b2Vec2(0.0, 0.0)
  }
  
  /// Implement b2Shape.
  open override func clone() -> b2Shape {
    let clone = b2CircleShape()
    clone.m_radius = m_radius
    clone.m_p = m_p
    return clone
  }
  
  /// @see b2Shape::GetChildCount
  open override var childCount: Int {
    return 1
  }
  
  /// Implement b2Shape.
  open override func testPoint(transform: b2Transform, point: b2Vec2) -> Bool {
    let center = transform.p + b2Mul(transform.q, m_p)
    let d = p - center
    return b2Dot(d, d) <= m_radius * m_radius
  }
  
  // Collision Detection in Interactive 3D Environments by Gino van den Bergen
  // From Section 3.1.2
  // x = s + a * r
  // norm(x) = radius
  open override func rayCast(_ output: inout b2RayCastOutput, input: b2RayCastInput, transform: b2Transform, childIndex: Int) -> Bool {
    let position = transform.p + b2Mul(transform.q, m_p)
    let s = input.p1 - position
    let b = b2Dot(s, s) - m_radius * m_radius
    
    // Solve quadratic equation.
    let r = input.p2 - input.p1
    let c =  b2Dot(s, r)
    let rr = b2Dot(r, r)
    let sigma = c * c - rr * b
    
    // Check for negative discriminant and short segment.
    if sigma < 0.0 || rr < b2_epsilon {
      return false
    }
    
    // Find the point of intersection of the line with the circle.
    var a = -(c + b2Sqrt(sigma))
    
    // Is the intersection point on the segment?
    if 0.0 <= a && a <= input.maxFraction * rr {
      a /= rr
      output.fraction = a
      output.normal = s + a * r
      output.normal.normalize()
      return true
    }
    
    return false
  }
  
  /// @see b2Shape::ComputeAABB
  open override func computeAABB(_ aabb: inout b2AABB, transform: b2Transform, childIndex: Int) {
    let p = transform.p + b2Mul(transform.q, m_p)
    aabb.lowerBound.set(p.x - m_radius, p.y - m_radius)
    aabb.upperBound.set(p.x + m_radius, p.y + m_radius)
  }
  
  /// @see b2Shape::ComputeMass
  open override func computeMass(density: b2Float) -> b2MassData {
    var massData = b2MassData()
    massData.mass = density * b2_pi * m_radius * m_radius
    massData.center = m_p
    
    // inertia about the local origin
    massData.I = massData.mass * (0.5 * m_radius * m_radius + b2Dot(m_p, m_p))
    return massData
  }
  
  /// Get the supporting vertex index in the given direction.
  open func getSupport(direction: b2Vec2) -> Int {
    return 0
  }
  
  /// Get the supporting vertex in the given direction.
  open func getSupportVertex(direction: b2Vec2) -> b2Vec2 {
    return m_p
  }
  
  /// Get the vertex count.
  open var vertexCount: Int { return 1 }
  
  /// Get a vertex by index. Used by b2Distance.
  open func vertex(index: Int) -> b2Vec2 {
    assert(index == 0)
    return m_p
  }

  open var p: b2Vec2 {
    get {
      return m_p_[0]
    }
    set {
      m_p_[0] = newValue
    }
  }
  
  // MARK: private variables

  /// Position
  var m_p_ = b2Array<b2Vec2>(count: 1, repeatedValue: b2Vec2())
  var m_p: b2Vec2 {
    get {
      return m_p_[0]
    }
    set {
      m_p_[0] = newValue
    }
  }
}
