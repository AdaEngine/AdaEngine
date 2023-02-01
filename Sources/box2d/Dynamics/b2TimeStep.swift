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



/// Profiling data. Times are in milliseconds.
public struct b2Profile {
    public init() {}
    public var step: b2Float = 0.0
    public var collide: b2Float = 0.0
    public var solve: b2Float = 0.0
    public var solveInit: b2Float = 0.0
    public var solveVelocity: b2Float = 0.0
    public var solvePosition: b2Float = 0.0
    public var broadphase: b2Float = 0.0
    public var solveTOI: b2Float = 0.0
}

public struct b2TimeStep {
    var dt: b2Float = 0.0       // time step
    var inv_dt: b2Float = 0.0   // inverse time step (0 if dt == 0).
    var dtRatio: b2Float = 0.0  // dt * inv_dt0
    var velocityIterations: Int = 0
    var positionIterations: Int = 0
    var warmStarting: Bool = false
}

open class b2Array<T> : CustomStringConvertible {
    var array = [T]()
    
    public init() {
    }
    
    public init(count: Int, repeatedValue: T) {
        array = [T](repeating: repeatedValue, count: count)
    }
    
    open func reserveCapacity(_ minimumCapacity: Int) {
        array.reserveCapacity(minimumCapacity)
    }
    
    open func append(_ newElement: T) {
        array.append(newElement)
    }
    
    open func insert(_ newElement: T, atIndex i: Int) {
        array.insert(newElement, at: i)
    }
    
    open func removeAtIndex(_ index: Int) -> T {
        return array.remove(at: index)
    }
    
    open func removeLast() {
        array.removeLast()
    }
    
    open func removeAll(_ keepCapacity: Bool = true) {
        array.removeAll(keepingCapacity: keepCapacity)
    }
    
    open subscript(index: Int) -> T {
        get {
            return array[index]
        }
        set {
            array[index] = newValue
        }
    }
    
    open func clone() -> b2Array {
        let clone = b2Array()
        clone.reserveCapacity(self.count)
        for e in self.array {
            clone.array.append(e)
        }
        return clone
    }
    
    open var count : Int {
        get {
            return array.count
        }
    }
    
    open var description: String {
        var s = "b2Array["
        for i in 0 ..< array.count {
            s += "\(array[i])"
            if i != array.count - 1 {
                s += ", "
            }
        }
        s += "]"
        return s
    }
}

/// This is an internal structure.
public struct b2Position {
    init(_ c: b2Vec2, _ a: b2Float) {
        self.c = c
        self.a = a
    }
    var c : b2Vec2
    var a : b2Float
}

/// This is an internal structure.
public struct b2Velocity {
    init(_ v: b2Vec2, _ w: b2Float) {
        self.v = v
        self.w = w
    }
    var v : b2Vec2
    var w : b2Float
}

/// Solver Data
public struct b2SolverData {
    var step = b2TimeStep()
    var positions = b2Array<b2Position>()
    var velocities = b2Array<b2Velocity>()
}


