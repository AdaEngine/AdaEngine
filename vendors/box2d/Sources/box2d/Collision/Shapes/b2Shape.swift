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
This holds the mass data computed for a shape.
*/
public struct b2MassData : CustomStringConvertible {
  /**
  The mass of the shape, usually in kilograms.
  */
  public var mass: b2Float = 0
  /**
  The position of the shape's centroid relative to the shape's origin.
  */
  public var center = b2Vec2()
  /**
  The rotational inertia of the shape about the local origin.
  */
  public var I: b2Float = 0
  
  public var description: String {
    return "b2MassData[mass=\(mass), center=\(center), I=\(I)]"
  }
}

public enum b2ShapeType: Int, CustomStringConvertible {
  case circle = 0
  case edge = 1
  case polygon = 2
  case chain = 3
  case typeCount = 4
  public var description: String {
    switch self {
    case .circle: return "circle"
    case .edge: return "edge"
    case .polygon: return "polygon"
    case .chain: return "chain"
    case .typeCount: return "typeCount"
    }
  }
}

// MARK: -
/**
A shape is used for collision detection. You can create a shape however you like.
Shapes used for simulation in b2World are created automatically when a b2Fixture
is created. Shapes may encapsulate a one or more child shapes.
*/
open class b2Shape : CustomStringConvertible {
  
  public init() {
    m_type = b2ShapeType.circle
    m_radius = 0
  }
  /**
  Clone the concrete shape using the provided allocator.
  */
  open func clone() -> b2Shape {
    fatalError("must override")
  }
  /**
  Get the type of this shape. You can use this to down cast to the concrete shape.
  
  - returns: the shape type.
  */
  open var type: b2ShapeType {
    return m_type
  }
  /**
  Get the number of child primitives.
  */
  open var childCount: Int {
    fatalError("must override")
  }
  /**
  Test a point for containment in this shape. This only works for convex shapes.
  
  - parameter transform: the shape world transform.
  - parameter point: a point in world coordinates.
  */
  open func testPoint(transform: b2Transform, point: b2Vec2) -> Bool {
    fatalError("must override")
  }
  /**
  Cast a ray against a child shape.
  
  - parameter output: the ray-cast results.
  - parameter input: the ray-cast input parameters.
  - parameter transform: the transform to be applied to the shape.
  - parameter childIndex: the child shape index
  */
  open func rayCast(_ output: inout b2RayCastOutput, input: b2RayCastInput, transform: b2Transform, childIndex: Int) -> Bool {
    fatalError("must override")
  }
  /**
  Given a transform, compute the associated axis aligned bounding box for a child shape.
  
  - parameter aabb: returns the axis aligned box.
  - parameter xf: the world transform of the shape.
  - parameter childIndex: the child shape
  */
  open func computeAABB(_ aabb: inout b2AABB, transform: b2Transform, childIndex: Int) {
    fatalError("must override")
  }
  /**
  Compute the mass properties of this shape using its dimensions and density.
  The inertia tensor is computed about the local origin.
  
  - parameter massData: returns the mass data for this shape.
  - parameter density: the density in kilograms per meter squared.
  */
  open func computeMass(density: b2Float) -> b2MassData {
    fatalError("must override")
  }
  
  open var description: String {
    return "b2Shape[type=\(m_type), radius=\(m_radius)]"
  }
  
  // MARK: private variables
  
  var m_type: b2ShapeType
  var m_radius: b2Float
  open var radius: b2Float {
    get { return m_radius }
    set { m_radius = newValue }
  }
}
