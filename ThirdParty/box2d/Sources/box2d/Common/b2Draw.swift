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

/// Color for debug drawing. Each value has the range [0,1].
// type checked
public struct b2Color : CustomStringConvertible {
    public var r: Float, g: Float, b: Float
    public init() {
        r = 0.0
        g = 0.0
        b = 0.0
    }
    public init(_ r: Float, _ g: Float, _ b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }
    public mutating func set(_ r: Float, _ g: Float, _ b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }
    public var description: String {
        return "b2Color[\(r),\(g),\(b)]"
    }
}

public struct b2DrawFlags {
    /// draw shapes
    public static let shapeBit: UInt32        = 0x0001
    /// draw joint connections
    public static let jointBit: UInt32        = 0x0002
    /// draw axis aligned bounding boxes
    public static let aabbBit: UInt32         = 0x0004
    /// draw broad-phase pairs
    public static let pairBit: UInt32         = 0x0008
    /// draw center of mass frame
    public static let centerOfMassBit: UInt32 = 0x0010
}

/// Implement and register this class with a b2World to provide debug drawing of physics
/// entities in your game.
// type checked
public protocol b2Draw {
    /// Get the drawing flags.
    var flags: UInt32 { get }
    
    /// Draw a closed polygon provided in CCW order.
    func drawPolygon(_ vertices: [b2Vec2], _ color: b2Color)
    
    /// Draw a solid closed polygon provided in CCW order.
    func drawSolidPolygon(_ vertices: [b2Vec2], _ color: b2Color)
    
    /// Draw a circle.
    func drawCircle(_ center: b2Vec2, _ radius: b2Float, _ color: b2Color)
    
    /// Draw a solid circle.
    func drawSolidCircle(_ center: b2Vec2, _ radius: b2Float, _ axis: b2Vec2, _ color: b2Color)
    
    /// Draw a line segment.
    func drawSegment(_ p1: b2Vec2, _ p2: b2Vec2, _ color: b2Color)
    
    /**
     Draw a transform. Choose your own length scale.
     
     - parameter xf: a transform.
     */
    func drawTransform(_ xf: b2Transform)
}

