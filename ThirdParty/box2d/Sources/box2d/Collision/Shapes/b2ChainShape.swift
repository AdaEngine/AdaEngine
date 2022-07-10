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

/// A chain shape is a free form sequence of line segments.
/// The chain has two-sided collision, so you can use inside and outside collision.
/// Therefore, you may use any winding order.
/// Since there may be many vertices, they are allocated using b2Alloc.
/// Connectivity information is used to create smooth collisions.
/// WARNING: The chain will not collide properly if there are self-intersections.
open class b2ChainShape : b2Shape {
  public override init() {
    m_vertices = b2Array<b2Vec2>()
    m_hasPrevVertex = false
    m_hasNextVertex = false
    super.init()
    m_type = b2ShapeType.chain
    m_radius = b2_polygonRadius
  }
  
  /**
  Create a loop. This automatically adjusts connectivity.
  
  - parameter vertices: an array of vertices, these are copied
  */
  open func createLoop(vertices: [b2Vec2]) {
    assert(m_vertices.count == 0)
    assert(vertices.count >= 3)
    for i in 1 ..< vertices.count {
      let v1 = vertices[i-1]
      let v2 = vertices[i]
      // If the code crashes here, it means your vertices are too close together.
      assert(b2DistanceSquared(v1, v2) > b2_linearSlop * b2_linearSlop)
    }
    
    for v in vertices {
      m_vertices.append(v)
    }
    m_vertices.append(m_vertices[0])
    assert(m_vertices.count == vertices.count + 1)
    m_prevVertex = m_vertices[m_count - 2]
    m_nextVertex = m_vertices[1]
    m_hasPrevVertex = true
    m_hasNextVertex = true
  }
  
  /**
  Create a chain with isolated end vertices.
  
  - parameter vertices: an array of vertices, these are copied
  */
  open func createChain(vertices: [b2Vec2]) {
    assert(m_vertices.count == 0)
    assert(vertices.count >= 2)
    for i in 1 ..< vertices.count {
      let v1 = vertices[i-1]
      let v2 = vertices[i]
      // If the code crashes here, it means your vertices are too close together.
      assert(b2DistanceSquared(v1, v2) > b2_linearSlop * b2_linearSlop)
    }
    
    for v in vertices {
      m_vertices.append(v)
    }
    
    m_hasPrevVertex = false
    m_hasNextVertex = false
    
    m_prevVertex.setZero()
    m_nextVertex.setZero()
  }
  
  /// Establish connectivity to a vertex that precedes the first vertex.
  /// Don't call this for loops.
  open func setPrevVertex(_ prevVertex: b2Vec2) {
    m_prevVertex = prevVertex
    m_hasPrevVertex = true
  }
  
  /// Establish connectivity to a vertex that follows the last vertex.
  /// Don't call this for loops.
  open func setNextVertex(_ nextVertex: b2Vec2) {
    m_nextVertex = nextVertex
    m_hasNextVertex = true
  }
  
  /// Implement b2Shape. Vertices are cloned using b2Alloc.
  open override func clone() -> b2Shape {
    let clone = b2ChainShape()
    clone.createChain(vertices: m_vertices.array)
    clone.m_prevVertex = m_prevVertex
    clone.m_nextVertex = m_nextVertex
    clone.m_hasPrevVertex = m_hasPrevVertex
    clone.m_hasNextVertex = m_hasNextVertex
    return clone
  }
  
  /// @see b2Shape::GetChildCount
  open override var childCount: Int {
    return m_count - 1
  }
  
  /// Get a child edge.
  open func getChildEdge(_ index : Int) -> b2EdgeShape {
    assert(0 <= index && index < m_vertices.count - 1)
    let edge = b2EdgeShape()
    edge.m_type = b2ShapeType.edge
    edge.m_radius = m_radius
    
    edge.m_vertex1 = m_vertices[index + 0]
    edge.m_vertex2 = m_vertices[index + 1]
    
    if index > 0 {
      edge.m_vertex0 = m_vertices[index - 1]
      edge.m_hasVertex0 = true
    }
    else {
      edge.m_vertex0 = m_prevVertex
      edge.m_hasVertex0 = m_hasPrevVertex
    }
    
    if index < m_count - 2 {
      edge.m_vertex3 = m_vertices[index + 2]
      edge.m_hasVertex3 = true
    }
    else {
      edge.m_vertex3 = m_nextVertex
      edge.m_hasVertex3 = m_hasNextVertex
    }
    return edge
  }
  
  /// This always return false.
  /// @see b2Shape::TestPoint
  open override func testPoint(transform: b2Transform, point: b2Vec2) -> Bool {
    return false
  }
  
  /// Implement b2Soverride hape.
  open override func rayCast(_ output: inout b2RayCastOutput, input : b2RayCastInput, transform xf: b2Transform, childIndex : Int) -> Bool {
    assert(childIndex < m_vertices.count)
    
    let edgeShape = b2EdgeShape()
    
    let i1 = childIndex
    var i2 = childIndex + 1
    if i2 == m_vertices.count {
      i2 = 0
    }
    
    edgeShape.m_vertex1 = m_vertices[i1]
    edgeShape.m_vertex2 = m_vertices[i2]
    
    return edgeShape.rayCast(&output, input: input, transform: xf, childIndex: 0)
  }
  
  /// @see b2Shape::ComputeAABB
  open override func computeAABB(_ aabb: inout b2AABB, transform: b2Transform, childIndex: Int) {
    assert(childIndex < m_vertices.count)
    
    let i1 = childIndex
    var i2 = childIndex + 1
    if i2 == m_count {
      i2 = 0
    }
    
    let v1 = b2Mul(transform, m_vertices[i1])
    let v2 = b2Mul(transform, m_vertices[i2])
    
    aabb.lowerBound = b2Min(v1, v2)
    aabb.upperBound = b2Max(v1, v2)
  }
  
  /// Chains have zero mass.
  /// @see b2Shape::ComputeMass
  open override func computeMass(density: b2Float) -> b2MassData {
    var massData = b2MassData()
    massData.mass = 0.0
    massData.center.setZero()
    massData.I = 0.0
    return massData
  }
  
  // MARK: private variables
  
  /// The vertices. Owned by this class.
  var m_vertices = b2Array<b2Vec2>()
  
  /// The vertex count.
  var m_count : Int {
    return m_vertices.count
  }
  
  var m_prevVertex = b2Vec2(), m_nextVertex = b2Vec2()
  var m_hasPrevVertex : Bool, m_hasNextVertex : Bool
}
