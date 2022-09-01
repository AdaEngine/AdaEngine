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



public enum b2JointType : CustomStringConvertible {
  case unknownJoint
  case revoluteJoint
  case prismaticJoint
  case distanceJoint
  case pulleyJoint
  case mouseJoint
  case gearJoint
  case wheelJoint
  case weldJoint
  case frictionJoint
  case ropeJoint
  case motorJoint
  public var description: String {
    switch self {
    case .unknownJoint: return "unknownJoint"
    case .revoluteJoint: return "revoluteJoint"
    case .prismaticJoint: return "prismaticJoint"
    case .distanceJoint: return "distanceJoint"
    case .pulleyJoint: return "pulleyJoint"
    case .mouseJoint: return "mouseJoint"
    case .gearJoint: return "gearJoint"
    case .wheelJoint: return "wheelJoint"
    case .weldJoint: return "weldJoint"
    case .frictionJoint: return "frictionJoint"
    case .ropeJoint: return "ropeJoint"
    case .motorJoint: return "motorJoint"
    }
  }
}

public enum b2LimitState : CustomStringConvertible {
  case inactiveLimit
  case atLowerLimit
  case atUpperLimit
  case equalLimits
  public var description: String {
    switch self {
    case .inactiveLimit: return "inactiveLimit"
    case .atLowerLimit: return "atLowerLimit"
    case .atUpperLimit: return "atUpperLimit"
    case .equalLimits: return "equalLimits"
    }
  }
}

public struct b2Jacobian {
  var linear: b2Vec2
  var angularA: b2Float
  var angularB: b2Float
}

// MARK: -
/// A joint edge is used to connect bodies and joints together
/// in a joint graph where each body is a node and each joint
/// is an edge. A joint edge belongs to a doubly linked list
/// maintained in each attached body. Each joint has two joint
/// nodes, one for each attached body.
open class b2JointEdge {
  init(joint: b2Joint) {
    self.joint = joint
  }
  var other: b2Body! = nil       ///< provides quick access to the other body attached.
  unowned var joint: b2Joint ///< the joint ** parent **
  var prev: b2JointEdge? = nil   ///< the previous joint edge in the body's joint list
  var next: b2JointEdge? = nil   ///< the next joint edge in the body's joint list
}

// MARK: -
/// Joint definitions are used to construct joints.
open class b2JointDef {
  public init() {
    type = b2JointType.unknownJoint
    userData = nil
    bodyA = nil
    bodyB = nil
    collideConnected = false
  }
  
  /// The joint type is set automatically for concrete joint types.
  open var type: b2JointType
  
  /// Use this to attach application specific data to your joints.
  open var userData: AnyObject?
  
  /// The first attached body.
  open var bodyA: b2Body!
  
  /// The second attached body.
  open var bodyB: b2Body!
  
  /// Set this flag to true if the attached bodies should collide.
  open var collideConnected: Bool
}

// MARK: -
/// various fashions. Some joints also feature limits and motors.
open class b2Joint {
  /// Get the type of the concrete joint.
  open var type: b2JointType {
    return m_type
  }
  
  /// Get the first body attached to this joint.
  open var bodyA: b2Body {
    return m_bodyA
  }
  
  /// Get the second body attached to this joint.
  open var bodyB: b2Body {
    return m_bodyB
  }
  
  /// Get the anchor point on bodyA in world coordinates.
  open var anchorA: b2Vec2 {
    fatalError("must override")
  }
  
  /// Get the anchor point on bodyB in world coordinates.
  open var anchorB: b2Vec2 {
    fatalError("must override")
  }
  
  /// Get the reaction force on bodyB at the joint anchor in Newtons.
  open func getReactionForce(inverseTimeStep inv_dt: b2Float) -> b2Vec2 {
    fatalError("must override")
  }
  
  /// Get the reaction torque on bodyB in N*m.
  open func getReactionTorque(inverseTimeStep inv_dt: b2Float) -> b2Float {
    fatalError("must override")
  }
  
  /// Get the next joint the world joint list.
  open func getNext() -> b2Joint? {
    return m_next
  }
  
  /// Get the user data pointer.
  open var userData: AnyObject? {
    get {
      return m_userData
    }
    set {
      setUserData(newValue)
    }
  }
  
  /// Set the user data pointer.
  open func setUserData(_ data: AnyObject?) {
      m_userData = data
  }
  
  /// Short-cut function to determine if either body is inactive.
  open var isActive: Bool {
    return m_bodyA.isActive && m_bodyB.isActive
  }
  
  /// Get collide connected.
  /// Note: modifying the collide connect flag won't work correctly because
  /// the flag is only checked when fixture AABBs begin to overlap.
  open var collideConnected: Bool {
    return m_collideConnected
  }
  
  /// Dump this joint to the log file.
  open func dump() { print("// Dump is not supported for this joint type."); }
  
  /// Shift the origin for any points stored in world coordinates.
  open func shiftOrigin(_ newOrigin: b2Vec2) { }
  
  // MARK: private methods
  
  class func create(_ def: b2JointDef) -> b2Joint {
    var joint: b2Joint
    
    switch def.type {
    case .distanceJoint:
      joint = b2DistanceJoint(def as! b2DistanceJointDef)
  
    case .mouseJoint:
      joint = b2MouseJoint(def as! b2MouseJointDef)
  
    case .prismaticJoint:
      joint = b2PrismaticJoint(def as! b2PrismaticJointDef)
  
    case .revoluteJoint:
      joint = b2RevoluteJoint(def as! b2RevoluteJointDef)
  
    case .pulleyJoint:
      joint = b2PulleyJoint(def as! b2PulleyJointDef)
  
    case .gearJoint:
      joint = b2GearJoint(def as! b2GearJointDef)
  
    case .wheelJoint:
      joint = b2WheelJoint(def as! b2WheelJointDef)
  
    case .weldJoint:
      joint = b2WeldJoint(def as! b2WeldJointDef)
  
    case .frictionJoint:
      joint = b2FrictionJoint(def as! b2FrictionJointDef)
  
    case .ropeJoint:
      joint = b2RopeJoint(def as! b2RopeJointDef)
  
    case .motorJoint:
      joint = b2MotorJoint(def as! b2MotorJointDef)
      
    default:
      fatalError("unknown joint type")
    }
    
    return joint
  }
  class func destroy(_ joint: b2Joint) {
  }
  
  init(_ def: b2JointDef) {
    assert(def.bodyA !== def.bodyB)
    
    m_type = def.type
    m_prev = nil
    m_next = nil
    m_bodyA = def.bodyA
    m_bodyB = def.bodyB
    m_index = 0
    m_collideConnected = def.collideConnected
    m_islandFlag = false
    m_userData = def.userData
    
    m_edgeA = b2JointEdge(joint: self)
    m_edgeA.other = nil
    m_edgeA.prev = nil
    m_edgeA.next = nil
    
    m_edgeB = b2JointEdge(joint: self)
    m_edgeB.other = nil
    m_edgeB.prev = nil
    m_edgeB.next = nil
  }
  
  func initVelocityConstraints(_ data: inout b2SolverData) {
    fatalError("must override")
  }
  func solveVelocityConstraints(_ data: inout b2SolverData) {
    fatalError("must override")
  }
  
  // This returns true if the position errors are within tolerance.
  func solvePositionConstraints(_ data: inout b2SolverData) -> Bool {
    fatalError("must override")
  }
  
  // MARK: private variables
  var m_type: b2JointType = b2JointType.unknownJoint
  var m_prev: b2Joint? = nil // ** linked list **
  var m_next: b2Joint? = nil // ** linked list **
  var m_edgeA : b2JointEdge! // ** owner **
  var m_edgeB : b2JointEdge! // ** owner **
  var m_bodyA: b2Body
  var m_bodyB: b2Body 
  
  var m_index: Int = 0
  
  var m_islandFlag: Bool = false
  var m_collideConnected: Bool = false
  
  var m_userData: AnyObject? = nil
}

