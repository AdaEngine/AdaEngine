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



let B2_DEBUG_SOLVER = true

open class b2VelocityConstraintPoint {
    var rA = b2Vec2()
    var rB = b2Vec2()
    var normalImpulse: b2Float = 0.0
    var tangentImpulse: b2Float = 0.0
    var normalMass: b2Float = 0.0
    var tangentMass: b2Float = 0.0
    var velocityBias: b2Float = 0.0
}

open class b2ContactVelocityConstraint {
    var points = [b2VelocityConstraintPoint]()
    var normal = b2Vec2()
    var normalMass = b2Mat22()
    var K = b2Mat22()
    var indexA: Int = 0
    var indexB: Int = 0
    var invMassA: b2Float = 0.0, invMassB: b2Float = 0.0
    var invIA: b2Float = 0.0, invIB: b2Float = 0.0
    var friction: b2Float = 0.0
    var restitution: b2Float = 0.0
    var tangentSpeed: b2Float = 0.0
    var pointCount: Int = 0
    var contactIndex: Int = 0
}

public struct b2ContactSolverDef {
    var step = b2TimeStep()
    var contacts = [b2Contact]()
    var count: Int = 0
    var positions = b2Array<b2Position>()
    var velocities = b2Array<b2Velocity>()
}

open class b2ContactSolver {
    init(_ def : b2ContactSolverDef) {
        m_step = def.step
        m_count = def.count
        m_positionConstraints = [b2ContactPositionConstraint]()
        m_positionConstraints.reserveCapacity(m_count)
        m_velocityConstraints = [b2ContactVelocityConstraint]()
        m_velocityConstraints.reserveCapacity(m_count)
        m_positions = def.positions
        m_velocities = def.velocities
        m_contacts = def.contacts
        
        // Initialize position independent portions of the constraints.
        for i in 0 ..< m_count {
            let contact = m_contacts[i]
            
            let fixtureA = contact.m_fixtureA
            let fixtureB = contact.m_fixtureB
            let shapeA = fixtureA?.shape
            let shapeB = fixtureB?.shape
            let radiusA = shapeA?.m_radius
            let radiusB = shapeB?.m_radius
            let bodyA = fixtureA?.body
            let bodyB = fixtureB?.body
            let manifold = contact.manifold
            
            let pointCount = manifold.pointCount
            assert(pointCount > 0)
            
            let vc = b2ContactVelocityConstraint()
            vc.friction = contact.m_friction
            vc.restitution = contact.m_restitution
            vc.tangentSpeed = contact.m_tangentSpeed
            vc.indexA = (bodyA?.m_islandIndex)!
            vc.indexB = (bodyB?.m_islandIndex)!
            vc.invMassA = (bodyA?.m_invMass)!
            vc.invMassB = (bodyB?.m_invMass)!
            vc.invIA = (bodyA?.m_invI)!
            vc.invIB = (bodyB?.m_invI)!
            vc.contactIndex = i
            vc.pointCount = pointCount
            vc.K.setZero()
            vc.normalMass.setZero()
            m_velocityConstraints.append(vc)
            
            let pc = b2ContactPositionConstraint()
            pc.indexA = (bodyA?.m_islandIndex)!
            pc.indexB = (bodyB?.m_islandIndex)!
            pc.invMassA = (bodyA?.m_invMass)!
            pc.invMassB = (bodyB?.m_invMass)!
            pc.localCenterA = (bodyA?.m_sweep.localCenter)!
            pc.localCenterB = (bodyB?.m_sweep.localCenter)!
            pc.invIA = (bodyA?.m_invI)!
            pc.invIB = (bodyB?.m_invI)!
            pc.localNormal = manifold.localNormal
            pc.localPoint = manifold.localPoint
            pc.pointCount = pointCount
            pc.radiusA = radiusA!
            pc.radiusB = radiusB!
            pc.type = manifold.type
            m_positionConstraints.append(pc)
            
            vc.points.reserveCapacity(pointCount)
            for j in 0 ..< pointCount {
                let cp = manifold.points[j]
                let vcp = b2VelocityConstraintPoint()
                
                if m_step.warmStarting {
                    vcp.normalImpulse = m_step.dtRatio * cp.normalImpulse
                    vcp.tangentImpulse = m_step.dtRatio * cp.tangentImpulse
                }
                else {
                    vcp.normalImpulse = 0.0
                    vcp.tangentImpulse = 0.0
                }
                
                vcp.rA.setZero()
                vcp.rB.setZero()
                vcp.normalMass = 0.0
                vcp.tangentMass = 0.0
                vcp.velocityBias = 0.0
                vc.points.append(vcp)
                
                pc.localPoints[j] = cp.localPoint
            }
        }
    }
    
    func initializeVelocityConstraints() {
        for i in 0 ..< m_count {
            let vc = m_velocityConstraints[i]
            let pc = m_positionConstraints[i]
            
            let radiusA = pc.radiusA
            let radiusB = pc.radiusB
            let manifold = m_contacts[vc.contactIndex].manifold
            
            let indexA = vc.indexA
            let indexB = vc.indexB
            
            let mA = vc.invMassA
            let mB = vc.invMassB
            let iA = vc.invIA
            let iB = vc.invIB
            let localCenterA = pc.localCenterA
            let localCenterB = pc.localCenterB
            
            let cA = m_positions[indexA].c
            let aA = m_positions[indexA].a
            let vA = m_velocities[indexA].v
            let wA = m_velocities[indexA].w
            
            let cB = m_positions[indexB].c
            let aB = m_positions[indexB].a
            let vB = m_velocities[indexB].v
            let wB = m_velocities[indexB].w
            
            assert(manifold.pointCount > 0)
            
            var xfA = b2Transform(), xfB = b2Transform()
            xfA.q.set(aA)
            xfB.q.set(aB)
            xfA.p = cA - b2Mul(xfA.q, localCenterA)
            xfB.p = cB - b2Mul(xfB.q, localCenterB)
            
            let worldManifold = b2WorldManifold()
            worldManifold.initialize(manifold: manifold, transformA: xfA, radiusA: radiusA, transformB: xfB, radiusB: radiusB)
            
            vc.normal = worldManifold.normal
            
            let pointCount = vc.pointCount
            for j in 0 ..< pointCount {
                let vcp = vc.points[j]
                
                vcp.rA = worldManifold.points[j] - cA
                vcp.rB = worldManifold.points[j] - cB
                
                let rnA = b2Cross(vcp.rA, vc.normal)
                let rnB = b2Cross(vcp.rB, vc.normal)
                
                let kNormal = mA + mB + iA * rnA * rnA + iB * rnB * rnB
                
                vcp.normalMass = kNormal > 0.0 ? 1.0 / kNormal : 0.0
                
                let tangent = b2Cross(vc.normal, 1.0)
                
                let rtA = b2Cross(vcp.rA, tangent)
                let rtB = b2Cross(vcp.rB, tangent)
                
                let kTangent = mA + mB + iA * rtA * rtA + iB * rtB * rtB
                
                vcp.tangentMass = kTangent > 0.0 ? 1.0 /  kTangent : 0.0
                
                // Setup a velocity bias for restitution.
                vcp.velocityBias = 0.0
                let vRel = b2Dot(vc.normal, vB + b2Cross(wB, vcp.rB) - vA - b2Cross(wA, vcp.rA))
                if vRel < -b2_velocityThreshold {
                    vcp.velocityBias = -vc.restitution * vRel
                }
            }
            
            // If we have two points, then prepare the block solver.
            if vc.pointCount == 2 {
                let vcp1 = vc.points[0]
                let vcp2 = vc.points[1]
                
                let rn1A = b2Cross(vcp1.rA, vc.normal)
                let rn1B = b2Cross(vcp1.rB, vc.normal)
                let rn2A = b2Cross(vcp2.rA, vc.normal)
                let rn2B = b2Cross(vcp2.rB, vc.normal)
                
                let k11 = mA + mB + iA * rn1A * rn1A + iB * rn1B * rn1B
                let k22 = mA + mB + iA * rn2A * rn2A + iB * rn2B * rn2B
                let k12 = mA + mB + iA * rn1A * rn2A + iB * rn1B * rn2B
                
                // Ensure a reasonable condition number.
                let k_maxConditionNumber: b2Float = 1000.0
                if k11 * k11 < k_maxConditionNumber * (k11 * k22 - k12 * k12) {
                    // K is safe to invert.
                    vc.K.ex.set(k11, k12)
                    vc.K.ey.set(k12, k22)
                    vc.normalMass = vc.K.getInverse()
                }
                else {
                    // The constraints are redundant, just use one.
                    // TODO_ERIN use deepest?
                    vc.pointCount = 1
                }
            }
        }
    }
    
    func warmStart() {
        // Warm start.
        for i in 0 ..< m_count {
            let vc = m_velocityConstraints[i]
            
            let indexA = vc.indexA
            let indexB = vc.indexB
            let mA = vc.invMassA
            let iA = vc.invIA
            let mB = vc.invMassB
            let iB = vc.invIB
            let pointCount = vc.pointCount
            
            var vA = m_velocities[indexA].v
            var wA = m_velocities[indexA].w
            var vB = m_velocities[indexB].v
            var wB = m_velocities[indexB].w
            
            let normal = vc.normal
            let tangent = b2Cross(normal, 1.0)
            
            for j in 0 ..< pointCount {
                let vcp = vc.points[j]
                let P = vcp.normalImpulse * normal + vcp.tangentImpulse * tangent
                wA -= iA * b2Cross(vcp.rA, P)
                vA -= mA * P
                wB += iB * b2Cross(vcp.rB, P)
                vB += mB * P
            }
            
            m_velocities[indexA].v = vA
            m_velocities[indexA].w = wA
            m_velocities[indexB].v = vB
            m_velocities[indexB].w = wB
        }
    }
    
    func solveVelocityConstraints() {
        for i in 0 ..< m_count {
            let vc = m_velocityConstraints[i]
            
            let indexA = vc.indexA
            let indexB = vc.indexB
            let mA = vc.invMassA
            let iA = vc.invIA
            let mB = vc.invMassB
            let iB = vc.invIB
            let pointCount = vc.pointCount
            
            var vA = m_velocities[indexA].v
            var wA = m_velocities[indexA].w
            var vB = m_velocities[indexB].v
            var wB = m_velocities[indexB].w
            
            let normal = vc.normal
            let tangent = b2Cross(normal, 1.0)
            let friction = vc.friction
            
            assert(pointCount == 1 || pointCount == 2)
            
            // Solve tangent constraints first because non-penetration is more important
            // than friction.
            for j in 0 ..< pointCount {
                let vcp = vc.points[j]
                
                // Relative velocity at contact
                let dv = vB + b2Cross(wB, vcp.rB) - vA - b2Cross(wA, vcp.rA)
                
                // Compute tangent force
                let vt = b2Dot(dv, tangent) - vc.tangentSpeed
                var lambda = vcp.tangentMass * (-vt)
                
                // b2Clamp the accumulated force
                let maxFriction = friction * vcp.normalImpulse
                let newImpulse = b2Clamp(vcp.tangentImpulse + lambda, -maxFriction, maxFriction)
                lambda = newImpulse - vcp.tangentImpulse
                vcp.tangentImpulse = newImpulse
                
                // Apply contact impulse
                let P = lambda * tangent
                
                vA -= mA * P
                wA -= iA * b2Cross(vcp.rA, P)
                
                vB += mB * P
                wB += iB * b2Cross(vcp.rB, P)
            }
            
            // Solve normal constraints
            if vc.pointCount == 1 {
                let vcp = vc.points[0]
                
                // Relative velocity at contact
                let dv = vB + b2Cross(wB, vcp.rB) - vA - b2Cross(wA, vcp.rA)
                
                // Compute normal impulse
                let vn = b2Dot(dv, normal)
                var lambda = -vcp.normalMass * (vn - vcp.velocityBias)
                
                // b2Clamp the accumulated impulse
                let newImpulse = max(vcp.normalImpulse + lambda, 0.0)
                lambda = newImpulse - vcp.normalImpulse
                vcp.normalImpulse = newImpulse
                
                // Apply contact impulse
                let P = lambda * normal
                vA -= mA * P
                wA -= iA * b2Cross(vcp.rA, P)
                
                vB += mB * P
                wB += iB * b2Cross(vcp.rB, P)
            }
            else {
                // Block solver developed in collaboration with Dirk Gregorius (back in 01/07 on Box2D_Lite).
                // Build the mini LCP for this contact patch
                //
                // vn = A * x + b, vn >= 0, , vn >= 0, x >= 0 and vn_i * x_i = 0 with i = 1..2
                //
                // A = J * W * JT and J = ( -n, -r1 x n, n, r2 x n )
                // b = vn0 - velocityBias
                //
                // The system is solved using the "Total enumeration method" (s. Murty). The complementary constraint vn_i * x_i
                // implies that we must have in any solution either vn_i = 0 or x_i = 0. So for the 2D contact problem the cases
                // vn1 = 0 and vn2 = 0, x1 = 0 and x2 = 0, x1 = 0 and vn2 = 0, x2 = 0 and vn1 = 0 need to be tested. The first valid
                // solution that satisfies the problem is chosen.
                //
                // In order to account of the accumulated impulse 'a' (because of the iterative nature of the solver which only requires
                // that the accumulated impulse is clamped and not the incremental impulse) we change the impulse variable (x_i).
                //
                // Substitute:
                //
                // x = a + d
                //
                // a := old total impulse
                // x := new total impulse
                // d := incremental impulse
                //
                // For the current iteration we extend the formula for the incremental impulse
                // to compute the new total impulse:
                //
                // vn = A * d + b
                //    = A * (x - a) + b
                //    = A * x + b - A * a
                //    = A * x + b'
                // b' = b - A * a
                
                var cp1 = vc.points[0]
                var cp2 = vc.points[1]
                
                let a = b2Vec2(cp1.normalImpulse, cp2.normalImpulse)
                assert(a.x >= 0.0 && a.y >= 0.0)
                
                // Relative velocity at contact
                var dv1 = vB + b2Cross(wB, cp1.rB) - vA - b2Cross(wA, cp1.rA)
                var dv2 = vB + b2Cross(wB, cp2.rB) - vA - b2Cross(wA, cp2.rA)
                
                // Compute normal velocity
                var vn1 = b2Dot(dv1, normal)
                var vn2 = b2Dot(dv2, normal)
                
                var b = b2Vec2()
                b.x = vn1 - cp1.velocityBias
                b.y = vn2 - cp2.velocityBias
                
                // Compute b'
                b -= b2Mul(vc.K, a)
                
                let k_errorTol: b2Float = 1e-3
                //B2_NOT_USED(k_errorTol)
                
                while true {
                    //
                    // Case 1: vn = 0
                    //
                    // 0 = A * x + b'
                    //
                    // Solve for x:
                    //
                    // x = - inv(A) * b'
                    //
                    var x = -b2Mul(vc.normalMass, b)
                    
                    if x.x >= 0.0 && x.y >= 0.0 {
                        // Get the incremental impulse
                        let d = x - a
                        
                        // Apply incremental impulse
                        let P1 = d.x * normal
                        let P2 = d.y * normal
                        vA -= mA * (P1 + P2)
                        wA -= iA * (b2Cross(cp1.rA, P1) + b2Cross(cp2.rA, P2))
                        
                        vB += mB * (P1 + P2)
                        wB += iB * (b2Cross(cp1.rB, P1) + b2Cross(cp2.rB, P2))
                        
                        // Accumulate
                        cp1.normalImpulse = x.x
                        cp2.normalImpulse = x.y
                        
#if B2_DEBUG_SOLVER
                        // Postconditions
                        dv1 = vB + b2Cross(wB, cp1.rB) - vA - b2Cross(wA, cp1.rA)
                        dv2 = vB + b2Cross(wB, cp2.rB) - vA - b2Cross(wA, cp2.rA)
                        
                        // Compute normal velocity
                        vn1 = b2Dot(dv1, normal)
                        vn2 = b2Dot(dv2, normal)
                        
                        assert(abs(vn1 - cp1.velocityBias) < k_errorTol)
                        assert(abs(vn2 - cp2.velocityBias) < k_errorTol)
#endif
                        break
                    }
                    
                    //
                    // Case 2: vn1 = 0 and x2 = 0
                    //
                    //   0 = a11 * x1 + a12 * 0 + b1'
                    // vn2 = a21 * x1 + a22 * 0 + b2'
                    //
                    x.x = -cp1.normalMass * b.x
                    x.y = 0.0
                    vn1 = 0.0
                    vn2 = vc.K.ex.y * x.x + b.y
                    
                    if x.x >= 0.0 && vn2 >= 0.0 {
                        // Get the incremental impulse
                        let d = x - a
                        
                        // Apply incremental impulse
                        let P1 = d.x * normal
                        let P2 = d.y * normal
                        vA -= mA * (P1 + P2)
                        wA -= iA * (b2Cross(cp1.rA, P1) + b2Cross(cp2.rA, P2))
                        
                        vB += mB * (P1 + P2)
                        wB += iB * (b2Cross(cp1.rB, P1) + b2Cross(cp2.rB, P2))
                        
                        // Accumulate
                        cp1.normalImpulse = x.x
                        cp2.normalImpulse = x.y
                        
#if B2_DEBUG_SOLVER
                        // Postconditions
                        dv1 = vB + b2Cross(wB, cp1.rB) - vA - b2Cross(wA, cp1.rA)
                        
                        // Compute normal velocity
                        vn1 = b2Dot(dv1, normal)
                        
                        assert(abs(vn1 - cp1.velocityBias) < k_errorTol)
#endif
                        break
                    }
                    
                    
                    //
                    // Case 3: vn2 = 0 and x1 = 0
                    //
                    // vn1 = a11 * 0 + a12 * x2 + b1'
                    //   0 = a21 * 0 + a22 * x2 + b2'
                    //
                    x.x = 0.0
                    x.y = -cp2.normalMass * b.y
                    vn1 = vc.K.ey.x * x.y + b.x
                    vn2 = 0.0
                    
                    if x.y >= 0.0 && vn1 >= 0.0 {
                        // Resubstitute for the incremental impulse
                        let d = x - a
                        
                        // Apply incremental impulse
                        let P1 = d.x * normal
                        let P2 = d.y * normal
                        vA -= mA * (P1 + P2)
                        wA -= iA * (b2Cross(cp1.rA, P1) + b2Cross(cp2.rA, P2))
                        
                        vB += mB * (P1 + P2)
                        wB += iB * (b2Cross(cp1.rB, P1) + b2Cross(cp2.rB, P2))
                        
                        // Accumulate
                        cp1.normalImpulse = x.x
                        cp2.normalImpulse = x.y
                        
#if B2_DEBUG_SOLVER
                        // Postconditions
                        dv2 = vB + b2Cross(wB, cp2.rB) - vA - b2Cross(wA, cp2.rA)
                        
                        // Compute normal velocity
                        vn2 = b2Dot(dv2, normal)
                        
                        assert(abs(vn2 - cp2.velocityBias) < k_errorTol)
#endif
                        break
                    }
                    
                    //
                    // Case 4: x1 = 0 and x2 = 0
                    //
                    // vn1 = b1
                    // vn2 = b2
                    x.x = 0.0
                    x.y = 0.0
                    vn1 = b.x
                    vn2 = b.y
                    
                    if vn1 >= 0.0 && vn2 >= 0.0 {
                        // Resubstitute for the incremental impulse
                        let d = x - a
                        
                        // Apply incremental impulse
                        let P1 = d.x * normal
                        let P2 = d.y * normal
                        vA -= mA * (P1 + P2)
                        wA -= iA * (b2Cross(cp1.rA, P1) + b2Cross(cp2.rA, P2))
                        
                        vB += mB * (P1 + P2)
                        wB += iB * (b2Cross(cp1.rB, P1) + b2Cross(cp2.rB, P2))
                        
                        // Accumulate
                        cp1.normalImpulse = x.x
                        cp2.normalImpulse = x.y
                        
                        break
                    }
                    
                    // No solution, give up. This is hit sometimes, but it doesn't seem to matter.
                    break
                }
            }
            
            m_velocities[indexA].v = vA
            m_velocities[indexA].w = wA
            m_velocities[indexB].v = vB
            m_velocities[indexB].w = wB
        }
    }
    
    func storeImpulses() {
        for i in 0 ..< m_count {
            let vc = m_velocityConstraints[i]
            let manifold = m_contacts[vc.contactIndex].manifold
            
            for j in 0 ..< vc.pointCount {
                manifold.points[j].normalImpulse = vc.points[j].normalImpulse
                manifold.points[j].tangentImpulse = vc.points[j].tangentImpulse
            }
        }
    }
    
    func solvePositionConstraints() -> Bool {
        var minSeparation: b2Float = 0.0
        
        for i in 0 ..< m_count {
            let pc = m_positionConstraints[i]
            
            let indexA = pc.indexA
            let indexB = pc.indexB
            let localCenterA = pc.localCenterA
            let mA = pc.invMassA
            let iA = pc.invIA
            let localCenterB = pc.localCenterB
            let mB = pc.invMassB
            let iB = pc.invIB
            let pointCount = pc.pointCount
            
            var cA = m_positions[indexA].c
            var aA = m_positions[indexA].a
            
            var cB = m_positions[indexB].c
            var aB = m_positions[indexB].a
            
            // Solve normal constraints
            for j in 0 ..< pointCount {
                var xfA = b2Transform(), xfB = b2Transform()
                xfA.q.set(aA)
                xfB.q.set(aB)
                xfA.p = cA - b2Mul(xfA.q, localCenterA)
                xfB.p = cB - b2Mul(xfB.q, localCenterB)
                
                let psm = b2PositionSolverManifold()
                psm.initialize(pc, xfA, xfB, j)
                let normal = psm.normal
                
                let point = psm.point
                let separation = psm.separation
                
                let rA = point - cA
                let rB = point - cB
                
                // Track max constraint error.
                minSeparation = min(minSeparation, separation)
                
                // Prevent large corrections and allow slop.
                let C = b2Clamp(b2_baumgarte * (separation + b2_linearSlop), -b2_maxLinearCorrection, 0.0)
                
                // Compute the effective mass.
                let rnA = b2Cross(rA, normal)
                let rnB = b2Cross(rB, normal)
                let K = mA + mB + iA * rnA * rnA + iB * rnB * rnB
                
                // Compute normal impulse
                let impulse = K > 0.0 ? -C / K : 0.0
                
                let P = impulse * normal
                
                cA -= mA * P
                aA -= iA * b2Cross(rA, P)
                
                cB += mB * P
                aB += iB * b2Cross(rB, P)
            }
            
            m_positions[indexA].c = cA
            m_positions[indexA].a = aA
            
            m_positions[indexB].c = cB
            m_positions[indexB].a = aB
        }
        
        // We can't expect minSpeparation >= -b2_linearSlop because we don't
        // push the separation above -b2_linearSlop.
        return minSeparation >= -3.0 * b2_linearSlop
    }
    
    func solveTOIPositionConstraints(_ toiIndexA: Int, _ toiIndexB: Int) -> Bool {
        var minSeparation: b2Float = 0.0
        
        for i in 0 ..< m_count {
            let pc = m_positionConstraints[i]
            
            let indexA = pc.indexA
            let indexB = pc.indexB
            let localCenterA = pc.localCenterA
            let localCenterB = pc.localCenterB
            let pointCount = pc.pointCount
            
            var mA: b2Float = 0.0
            var iA: b2Float = 0.0
            if indexA == toiIndexA || indexA == toiIndexB {
                mA = pc.invMassA
                iA = pc.invIA
            }
            
            var mB: b2Float = 0.0
            var iB: b2Float = 0.0
            if indexB == toiIndexA || indexB == toiIndexB {
                mB = pc.invMassB
                iB = pc.invIB
            }
            
            var cA = m_positions[indexA].c
            var aA = m_positions[indexA].a
            
            var cB = m_positions[indexB].c
            var aB = m_positions[indexB].a
            
            // Solve normal constraints
            for j in 0 ..< pointCount {
                var xfA = b2Transform(), xfB = b2Transform()
                xfA.q.set(aA)
                xfB.q.set(aB)
                xfA.p = cA - b2Mul(xfA.q, localCenterA)
                xfB.p = cB - b2Mul(xfB.q, localCenterB)
                
                let psm = b2PositionSolverManifold()
                psm.initialize(pc, xfA, xfB, j)
                let normal = psm.normal
                
                let point = psm.point
                let separation = psm.separation
                
                let rA = point - cA
                let rB = point - cB
                
                // Track max constraint error.
                minSeparation = min(minSeparation, separation)
                
                // Prevent large corrections and allow slop.
                let C = b2Clamp(b2_toiBaugarte * (separation + b2_linearSlop), -b2_maxLinearCorrection, 0.0)
                
                // Compute the effective mass.
                let rnA = b2Cross(rA, normal)
                let rnB = b2Cross(rB, normal)
                let K = mA + mB + iA * rnA * rnA + iB * rnB * rnB
                
                // Compute normal impulse
                let impulse = K > 0.0 ? -C / K : 0.0
                
                let P = impulse * normal
                
                cA -= mA * P
                aA -= iA * b2Cross(rA, P)
                
                cB += mB * P
                aB += iB * b2Cross(rB, P)
            }
            
            m_positions[indexA].c = cA
            m_positions[indexA].a = aA
            
            m_positions[indexB].c = cB
            m_positions[indexB].a = aB
        }
        
        // We can't expect minSpeparation >= -b2_linearSlop because we don't
        // push the separation above -b2_linearSlop.
        return minSeparation >= -1.5 * b2_linearSlop
    }
    
    var m_step : b2TimeStep
    var m_positions : b2Array<b2Position>
    var m_velocities : b2Array<b2Velocity>
    var m_positionConstraints : [b2ContactPositionConstraint]
    var m_velocityConstraints : [b2ContactVelocityConstraint]
    var m_contacts : [b2Contact]
    var m_count : Int
}

open class b2ContactPositionConstraint {
    var localPoints = [b2Vec2](repeating: b2Vec2(), count: b2_maxManifoldPoints)
    var localNormal = b2Vec2()
    var localPoint = b2Vec2()
    var indexA = 0
    var indexB = 0
    var invMassA: b2Float = 0.0, invMassB: b2Float = 0.0
    var localCenterA = b2Vec2(), localCenterB = b2Vec2()
    var invIA: b2Float = 0, invIB: b2Float = 0
    var type: b2ManifoldType = .circles
    var radiusA: b2Float = 0, radiusB : b2Float = 0
    var pointCount = 0
}

internal class b2PositionSolverManifold {
    func initialize(_ pc: b2ContactPositionConstraint, _ xfA: b2Transform, _ xfB: b2Transform, _ index: Int) {
        assert(pc.pointCount > 0)
        
        switch pc.type {
        case .circles:
            let pointA = b2Mul(xfA, pc.localPoint)
            let pointB = b2Mul(xfB, pc.localPoints[0])
            normal = pointB - pointA
            normal.normalize()
            point = 0.5 * (pointA + pointB)
            separation = b2Dot(pointB - pointA, normal) - pc.radiusA - pc.radiusB
            
        case .faceA:
            normal = b2Mul(xfA.q, pc.localNormal)
            let planePoint = b2Mul(xfA, pc.localPoint)
            
            let clipPoint = b2Mul(xfB, pc.localPoints[index])
            separation = b2Dot(clipPoint - planePoint, normal) - pc.radiusA - pc.radiusB
            point = clipPoint
            
        case .faceB:
            normal = b2Mul(xfB.q, pc.localNormal)
            let planePoint = b2Mul(xfB, pc.localPoint)
            
            let clipPoint = b2Mul(xfA, pc.localPoints[index])
            separation = b2Dot(clipPoint - planePoint, normal) - pc.radiusA - pc.radiusB
            point = clipPoint
            
            // Ensure normal points from A to B
            normal = -normal
        }
    }
    
    var normal = b2Vec2()
    var point = b2Vec2()
    var separation: b2Float = 0.0
}

