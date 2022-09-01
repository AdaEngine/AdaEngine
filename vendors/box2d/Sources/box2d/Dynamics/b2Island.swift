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



/// This is an internal class.
open class b2Island {
    init(_ bodyCapacity: Int, _ contactCapacity: Int, _ jointCapacity: Int, _ listener: b2ContactListener?) {
        m_bodyCapacity = bodyCapacity
        m_contactCapacity = contactCapacity
        m_jointCapacity	 = jointCapacity
        
        m_listener = listener
        
        m_bodies = [b2Body]()
        m_bodies.reserveCapacity(bodyCapacity)
        m_contacts = [b2Contact]()
        m_contacts.reserveCapacity(contactCapacity)
        m_joints = [b2Joint]()
        m_joints.reserveCapacity(jointCapacity)
        
        m_velocities = b2Array<b2Velocity>()
        m_velocities.reserveCapacity(m_bodyCapacity)
        m_positions = b2Array<b2Position>()
        m_positions.reserveCapacity(m_bodyCapacity)
    }
    
    func reset(_ bodyCapacity: Int, _ contactCapacity: Int, _ jointCapacity: Int, _ listener: b2ContactListener?) {
        m_bodyCapacity = bodyCapacity
        m_contactCapacity = contactCapacity
        m_jointCapacity	 = jointCapacity
        
        m_listener = listener
        
        m_bodies.removeAll(keepingCapacity: true)
        m_bodies.reserveCapacity(bodyCapacity)
        m_contacts.removeAll(keepingCapacity: true)
        m_contacts.reserveCapacity(contactCapacity)
        m_joints.removeAll(keepingCapacity: true)
        m_joints.reserveCapacity(jointCapacity)
        
        m_velocities.removeAll(true)
        m_velocities.reserveCapacity(m_bodyCapacity)
        m_positions.removeAll(true)
        m_positions.reserveCapacity(m_bodyCapacity)
    }
    
    func clear() {
        m_bodies.removeAll(keepingCapacity: true)
        m_contacts.removeAll(keepingCapacity: true)
        m_joints.removeAll(keepingCapacity: true)
    }
    
    func solve(_ profile: inout b2Profile, _ step: b2TimeStep, _ gravity: b2Vec2, _ allowSleep: Bool) {
        let timer = b2Timer()
        
        let h = step.dt
        
        // Integrate velocities and apply damping. Initialize the body state.
        m_positions.removeAll(true)
        m_velocities.removeAll(true)
        for i in 0 ..< m_bodyCount {
            let b = m_bodies[i]
            
            let c = b.m_sweep.c
            let a = b.m_sweep.a
            var v = b.m_linearVelocity
            var w = b.m_angularVelocity
            
            // Store positions for continuous collision.
            b.m_sweep.c0 = b.m_sweep.c
            b.m_sweep.a0 = b.m_sweep.a
            
            if b.m_type == b2BodyType.dynamicBody {
                // Integrate velocities.
                v += h * (b.m_gravityScale * gravity + b.m_invMass * b.m_force)
                w += h * b.m_invI * b.m_torque
                
                // Apply damping.
                // ODE: dv/dt + c * v = 0
                // Solution: v(t) = v0 * exp(-c * t)
                // Time step: v(t + dt) = v0 * exp(-c * (t + dt)) = v0 * exp(-c * t) * exp(-c * dt) = v * exp(-c * dt)
                // v2 = exp(-c * dt) * v1
                // Pade approximation:
                // v2 = v1 * 1 / (1 + c * dt)
                v *= 1.0 / (1.0 + h * b.m_linearDamping)
                w *= 1.0 / (1.0 + h * b.m_angularDamping)
            }
            
            m_positions.append(b2Position(c, a))
            m_velocities.append(b2Velocity(v, w))
        }
        
        timer.reset()
        
        // Solver data
        var solverData = b2SolverData()
        solverData.step = step
        solverData.positions = m_positions
        solverData.velocities = m_velocities
        
        // Initialize velocity constraints.
        var contactSolverDef = b2ContactSolverDef()
        contactSolverDef.step = step
        contactSolverDef.contacts = m_contacts
        contactSolverDef.count = m_contactCount
        contactSolverDef.positions = m_positions
        contactSolverDef.velocities = m_velocities
        
        let contactSolver = b2ContactSolver(contactSolverDef)
        contactSolver.initializeVelocityConstraints()
        
        if step.warmStarting {
            contactSolver.warmStart()
        }
        
        for i in 0 ..< m_jointCount {
            m_joints[i].initVelocityConstraints(&solverData)
        }
        
        profile.solveInit = timer.milliseconds
        
        // Solve velocity constraints
        timer.reset()
        for _ in 0 ..< step.velocityIterations {
            for j in 0 ..< m_jointCount {
                m_joints[j].solveVelocityConstraints(&solverData)
            }
            
            contactSolver.solveVelocityConstraints()
        }
        
        // Store impulses for warm starting
        contactSolver.storeImpulses()
        profile.solveVelocity = timer.milliseconds
        
        // Integrate positions
        for i in 0 ..< m_bodyCount {
            var c = m_positions[i].c
            var a = m_positions[i].a
            var v = m_velocities[i].v
            var w = m_velocities[i].w
            
            // Check for large velocities
            let translation = h * v
            if b2Dot(translation, translation) > b2_maxTranslationSquared {
                let ratio = b2_maxTranslation / translation.length()
                v *= ratio
            }
            
            let rotation = h * w
            if rotation * rotation > b2_maxRotationSquared {
                let ratio = b2_maxRotation / abs(rotation)
                w *= ratio
            }
            
            // Integrate
            c += h * v
            a += h * w
            
            m_positions[i].c = c
            m_positions[i].a = a
            m_velocities[i].v = v
            m_velocities[i].w = w
        }
        
        // Solve position constraints
        timer.reset()
        var positionSolved = false
        for _ in 0 ..< step.positionIterations {
            let contactsOkay = contactSolver.solvePositionConstraints()
            
            var jointsOkay = true
            for i2 in 0 ..< m_jointCount {
                let jointOkay = m_joints[i2].solvePositionConstraints(&solverData)
                jointsOkay = jointsOkay && jointOkay
            }
            
            if contactsOkay && jointsOkay {
                // Exit early if the position errors are small.
                positionSolved = true
                break
            }
        }
        
        // Copy state buffers back to the bodies
        for i in 0 ..< m_bodyCount {
            let body = m_bodies[i]
            body.m_sweep.c = m_positions[i].c
            body.m_sweep.a = m_positions[i].a
            body.m_linearVelocity = m_velocities[i].v
            body.m_angularVelocity = m_velocities[i].w
            body.synchronizeTransform()
        }
        
        profile.solvePosition = timer.milliseconds
        
        report(contactSolver.m_velocityConstraints)
        
        if allowSleep {
            var minSleepTime = b2_maxFloat
            
            let linTolSqr = b2_linearSleepTolerance * b2_linearSleepTolerance
            let angTolSqr = b2_angularSleepTolerance * b2_angularSleepTolerance
            
            for i in 0 ..< m_bodyCount {
                let b = m_bodies[i]
                if b.type == b2BodyType.staticBody {
                    continue
                }
                
                if (b.m_flags & b2Body.Flags.autoSleepFlag) == 0 ||
                    b.m_angularVelocity * b.m_angularVelocity > angTolSqr ||
                    b2Dot(b.m_linearVelocity, b.m_linearVelocity) > linTolSqr {
                    b.m_sleepTime = 0.0
                    minSleepTime = 0.0
                }
                else {
                    b.m_sleepTime += h
                    minSleepTime = min(minSleepTime, b.m_sleepTime)
                }
            }
            
            if minSleepTime >= b2_timeToSleep && positionSolved {
                for i in 0 ..< m_bodyCount {
                    let b = m_bodies[i]
                    b.setAwake(false)
                }
            }
        }
    }
    
    func solveTOI(_ subStep: b2TimeStep, _ toiIndexA: Int, _ toiIndexB: Int) {
        assert(toiIndexA < m_bodyCount)
        assert(toiIndexB < m_bodyCount)
        
        // Initialize the body state.
        m_positions.removeAll(true)
        m_velocities.removeAll(true)
        for i in 0 ..< m_bodyCount {
            let b = m_bodies[i]
            m_positions.append(b2Position(b.m_sweep.c, b.m_sweep.a))
            m_velocities.append(b2Velocity(b.m_linearVelocity, b.m_angularVelocity))
        }
        
        var contactSolverDef = b2ContactSolverDef()
        contactSolverDef.contacts = m_contacts
        contactSolverDef.count = m_contactCount
        contactSolverDef.step = subStep
        contactSolverDef.positions = m_positions
        contactSolverDef.velocities = m_velocities
        let contactSolver = b2ContactSolver(contactSolverDef)
        
        // Solve position constraints.
        for _ in 0 ..< subStep.positionIterations {
            let contactsOkay = contactSolver.solveTOIPositionConstraints(toiIndexA, toiIndexB)
            if contactsOkay {
                break
            }
        }
        
#if false
        // Is the new position really safe?
        for i in 0 ..< m_contactCount {
            let c = m_contacts[i]
            let fA = c.fixtureA
            let fB = c.fixtureB
            
            let bA = fA.body
            let bB = fB.body
            
            let indexA = c.childIndexA
            let indexB = c.childIndexB
            
            var input = b2DistanceInput()
            input.proxyA.set(fA.shape, indexA)
            input.proxyB.set(fB.shape, indexB)
            input.transformA = bA.transform
            input.transformB = bB.transform
            input.useRadii = false
            
            var output = b2DistanceOutput()
            var cache = b2SimplexCache()
            cache.count = 0
            b2Distance(&output, &cache, input)
            
            if output.distance == 0 || cache.count == 3 {
                cache.count += 0
            }
        }
#endif
        
        // Leap of faith to new safe state.
        m_bodies[toiIndexA].m_sweep.c0 = m_positions[toiIndexA].c
        m_bodies[toiIndexA].m_sweep.a0 = m_positions[toiIndexA].a
        m_bodies[toiIndexB].m_sweep.c0 = m_positions[toiIndexB].c
        m_bodies[toiIndexB].m_sweep.a0 = m_positions[toiIndexB].a
        
        // No warm starting is needed for TOI events because warm
        // starting impulses were applied in the discrete solver.
        contactSolver.initializeVelocityConstraints()
        
        // Solve velocity constraints.
        for _ in 0 ..< subStep.velocityIterations {
            contactSolver.solveVelocityConstraints()
        }
        
        // Don't store the TOI contact forces for warm starting
        // because they can be quite large.
        
        let h = subStep.dt
        
        // Integrate positions
        for i in 0 ..< m_bodyCount {
            var c = m_positions[i].c
            var a = m_positions[i].a
            var v = m_velocities[i].v
            var w = m_velocities[i].w
            
            // Check for large velocities
            let translation = h * v
            if b2Dot(translation, translation) > b2_maxTranslationSquared {
                let ratio = b2_maxTranslation / translation.length()
                v *= ratio
            }
            
            let rotation = h * w
            if rotation * rotation > b2_maxRotationSquared {
                let ratio = b2_maxRotation / abs(rotation)
                w *= ratio
            }
            
            // Integrate
            c += h * v
            a += h * w
            
            m_positions[i].c = c
            m_positions[i].a = a
            m_velocities[i].v = v
            m_velocities[i].w = w
            
            // Sync bodies
            let body = m_bodies[i]
            body.m_sweep.c = c
            body.m_sweep.a = a
            body.m_linearVelocity = v
            body.m_angularVelocity = w
            body.synchronizeTransform()
        }
        
        report(contactSolver.m_velocityConstraints)
    }
    
    func add(_ body: b2Body) {
        assert(m_bodyCount < m_bodyCapacity)
        body.m_islandIndex = m_bodyCount
        m_bodies.append(body)
    }
    
    func add(_ contact: b2Contact) {
        assert(m_contactCount < m_contactCapacity)
        m_contacts.append(contact)
    }
    
    func add(_ joint: b2Joint) {
        assert(m_jointCount < m_jointCapacity)
        m_joints.append(joint)
    }
    
    func report(_ constraints: [b2ContactVelocityConstraint]) {
        if m_listener == nil {
            return
        }
        
        for i in 0 ..< m_contactCount {
            let c = m_contacts[i]
            
            let vc = constraints[i]
            
            var impulse = b2ContactImpulse()
            impulse.count = vc.pointCount
            for j in 0 ..< vc.pointCount {
                impulse.normalImpulses[j] = vc.points[j].normalImpulse
                impulse.tangentImpulses[j] = vc.points[j].tangentImpulse
            }
            
            m_listener?.postSolve(c, impulse: impulse)
        }
    }
    
    var m_listener: b2ContactListener?
    
    var m_bodies: [b2Body]
    var m_contacts: [b2Contact]
    var m_joints: [b2Joint]
    
    var m_positions: b2Array<b2Position>
    var m_velocities: b2Array<b2Velocity>
    
    var m_bodyCount: Int { return m_bodies.count }
    var m_jointCount: Int { return m_joints.count }
    var m_contactCount: Int { return m_contacts.count }
    
    var m_bodyCapacity: Int
    var m_contactCapacity: Int
    var m_jointCapacity: Int
}
