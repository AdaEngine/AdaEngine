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

import Foundation

///
public struct b2RopeDef {
    init() {
        vertices = nil
        count = 0
        masses = nil
        gravity = b2Vec2()
        damping = 0.1
        k2 = 0.9
        k3 = 0.1
    }
    
    ///
    var vertices: [b2Vec2]!
    
    ///
    var count: Int
    
    ///
    var masses: [b2Float]!
    
    ///
    var gravity: b2Vec2
    
    ///
    var damping: b2Float
    
    /// Stretching stiffness
    var k2: b2Float
    
    /// Bending stiffness. Values above 0.5 can make the simulation blow up.
    var k3: b2Float
}

///
open class b2Rope {
    init() {
        m_count = 0
        m_ps = nil
        m_p0s = nil
        m_vs = nil
        m_ims = nil
        m_Ls = nil
        m_as = nil
        m_gravity = b2Vec2(0.0, 0.0)
        m_damping = 0.1
        m_k2 = 1.0
        m_k3 = 0.1
    }
    deinit {
    }
    
    ///
    func initialize(_ def: b2RopeDef) {
        assert(def.count >= 3)
        m_count = def.count
        m_ps = [b2Vec2](repeating: b2Vec2(), count: m_count)
        m_p0s = [b2Vec2](repeating: b2Vec2(), count: m_count)
        m_vs = [b2Vec2](repeating: b2Vec2(), count: m_count)
        m_ims = [b2Float](repeating: b2Float(0.0), count: m_count)
        
        for i in 0 ..< m_count {
            m_ps[i] = def.vertices[i]
            m_p0s[i] = def.vertices[i]
            m_vs[i].setZero()
            
            let m = def.masses[i]
            if m > 0.0 {
                m_ims[i] = 1.0 / m
            }
            else {
                m_ims[i] = 0.0
            }
        }
        
        let count2 = m_count - 1
        let count3 = m_count - 2
        m_Ls = [b2Float](repeating: b2Float(0.0), count: count2)
        m_as = [b2Float](repeating: b2Float(0.0), count: count3)
        
        for i in 0 ..< count2 {
            let p1 = m_ps[i]
            let p2 = m_ps[i+1]
            m_Ls[i] = b2Distance(p1, p2)
        }
        
        for i in 0 ..< count3 {
            let p1 = m_ps[i]
            let p2 = m_ps[i + 1]
            let p3 = m_ps[i + 2]
            
            let d1 = p2 - p1
            let d2 = p3 - p2
            
            let a = b2Cross(d1, d2)
            let b = b2Dot(d1, d2)
            
            m_as[i] = b2Atan2(a, b)
        }
        
        m_gravity = def.gravity
        m_damping = def.damping
        m_k2 = def.k2
        m_k3 = def.k3
    }
    
    ///
    func step(timeStep h: b2Float, iterations: Int) {
        if h == 0.0 {
            return
        }
        
        let d = exp(-h * m_damping)
        
        for i in 0 ..< m_count {
            m_p0s[i] = m_ps[i]
            if m_ims[i] > 0.0 {
                m_vs[i] += h * m_gravity
            }
            m_vs[i] *= d
            m_ps[i] += h * m_vs[i]
        }
        
        for _ in 0 ..< iterations {
            solveC2()
            solveC3()
            solveC2()
        }
        
        let inv_h = 1.0 / h
        for i in 0 ..< m_count {
            m_vs[i] = inv_h * (m_ps[i] - m_p0s[i])
        }
    }
    
    ///
    var vertexCount: Int {
        return m_count
    }
    
    ///
    var vertices: [b2Vec2] {
        return m_ps
    }
    
    ///
    func draw(_ draw: b2Draw) {
        let c = b2Color(0.4, 0.5, 0.7)
        
        for i in 0 ..< m_count - 1 {
            draw.drawSegment(m_ps[i], m_ps[i+1], c)
        }
    }
    
    ///
    func setAngle(_ angle: b2Float) {
        let count3 = m_count - 2
        for i in 0 ..< count3 {
            m_as[i] = angle
        }
    }
    
    func solveC2() {
        let count2 = m_count - 1
        
        for i in 0 ..< count2 {
            var p1 = m_ps[i]
            var p2 = m_ps[i + 1]
            
            var d = p2 - p1
            let L = d.normalize()
            
            let im1 = m_ims[i]
            let im2 = m_ims[i + 1]
            
            if im1 + im2 == 0.0 {
                continue
            }
            
            let s1 = im1 / (im1 + im2)
            let s2 = im2 / (im1 + im2)
            
            p1 -= m_k2 * s1 * (m_Ls[i] - L) * d
            p2 += m_k2 * s2 * (m_Ls[i] - L) * d
            
            m_ps[i] = p1
            m_ps[i + 1] = p2
        }
    }
    func solveC3() {
        let count3 = m_count - 2
        
        for i in 0 ..< count3 {
            var p1 = m_ps[i]
            var p2 = m_ps[i + 1]
            var p3 = m_ps[i + 2]
            
            let m1 = m_ims[i]
            let m2 = m_ims[i + 1]
            let m3 = m_ims[i + 2]
            
            let d1 = p2 - p1
            let d2 = p3 - p2
            
            let L1sqr = d1.lengthSquared()
            let L2sqr = d2.lengthSquared()
            
            if L1sqr * L2sqr == 0.0 {
                continue
            }
            
            let a = b2Cross(d1, d2)
            let b = b2Dot(d1, d2)
            
            var angle = b2Atan2(a, b)
            
            let Jd1 = (-1.0 / L1sqr) * d1.skew()
            let Jd2 = (1.0 / L2sqr) * d2.skew()
            
            let J1 = -Jd1
            let J2 = Jd1 - Jd2
            let J3 = Jd2
            
            var mass = m1 * b2Dot(J1, J1) + m2 * b2Dot(J2, J2) + m3 * b2Dot(J3, J3)
            if mass == 0.0 {
                continue
            }
            
            mass = 1.0 / mass
            
            var C = angle - m_as[i]
            
            while C > b2_pi {
                angle -= 2 * b2_pi
                C = angle - m_as[i]
            }
            
            while C < -b2_pi {
                angle += 2.0 * b2_pi
                C = angle - m_as[i]
            }
            
            let impulse = -m_k3 * mass * C
            
            p1 += (m1 * impulse) * J1
            p2 += (m2 * impulse) * J2
            p3 += (m3 * impulse) * J3
            
            m_ps[i] = p1
            m_ps[i + 1] = p2
            m_ps[i + 2] = p3
        }
    }
    
    var m_count: Int
    var m_ps: [b2Vec2]! = nil
    var m_p0s: [b2Vec2]! = nil
    var m_vs: [b2Vec2]! = nil
    
    var m_ims: [b2Float]! = nil
    
    var m_Ls: [b2Float]! = nil
    var m_as: [b2Float]! = nil
    
    var m_gravity: b2Vec2
    var m_damping: b2Float
    
    var m_k2: b2Float
    var m_k3: b2Float
}
