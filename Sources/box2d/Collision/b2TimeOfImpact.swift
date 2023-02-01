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

/// Input parameters for b2TimeOfImpact
public struct b2TOIInput {
    public init() {}
    public var proxyA = b2DistanceProxy()
    public var proxyB = b2DistanceProxy()
    public var sweepA = b2Sweep()
    public var sweepB = b2Sweep()
    public var tMax: b2Float = 0.0		// defines sweep interval [0, tMax]
}

// Output parameters for b2TimeOfImpact.
public struct b2TOIOutput {
    public enum State : CustomStringConvertible {
        case unknown
        case failed
        case overlapped
        case touching
        case separated
        public var description: String {
            switch self {
            case .unknown: return "unknown"
            case .failed: return "failed"
            case .overlapped: return "overlapped"
            case .touching: return "touching"
            case .separated: return "separated"
            }
        }
    }
    public init() {}
    
    public var state = State.unknown
    public var t: b2Float = 0
}

/// Compute the upper bound on time before two shapes penetrate. Time is represented as
/// a fraction between [0,tMax]. This uses a swept separating axis and may miss some intermediate,
/// non-tunneling collision. If you change the time interval, you should call this function
/// again.
/// Note: use b2Distance to compute the contact point and normal at the time of impact.
public func b2TimeOfImpact(_ output: inout b2TOIOutput, input: b2TOIInput) {
    let timer = b2Timer()
    
    b2_toiCalls += 1
    
    output.state = b2TOIOutput.State.unknown
    output.t = input.tMax
    
    let proxyA = input.proxyA
    let proxyB = input.proxyB
    
    var sweepA = input.sweepA
    var sweepB = input.sweepB
    
    // Large rotations can make the root finder fail, so we normalize the
    // sweep angles.
    sweepA.normalize()
    sweepB.normalize()
    
    let tMax = input.tMax
    
    let totalRadius = proxyA.m_radius + proxyB.m_radius
    let target = max(b2_linearSlop, totalRadius - 3.0 * b2_linearSlop)
    let tolerance = 0.25 * b2_linearSlop
    assert(target > tolerance)
    
    var t1: b2Float = 0.0
    let k_maxIterations = 20	// TODO_ERIN b2Settings
    var iter = 0
    
    // Prepare input for distance query.
    var cache = b2SimplexCache()
    cache.count = 0
    var distanceInput = b2DistanceInput()
    distanceInput.proxyA = input.proxyA
    distanceInput.proxyB = input.proxyB
    distanceInput.useRadii = false
    
    // The outer loop progressively attempts to compute new separating axes.
    // This loop terminates when an axis is repeated (no progress is made).
    while true {
        let xfA = sweepA.getTransform(beta: t1)
        let xfB = sweepB.getTransform(beta: t1)
        
        // Get the distance between shapes. We can also use the results
        // to get a separating axis.
        distanceInput.transformA = xfA
        distanceInput.transformB = xfB
        var distanceOutput = b2DistanceOutput()
        b2Distance(&distanceOutput, cache: &cache, input: distanceInput)
        
        // If the shapes are overlapped, we give up on continuous collision.
        if distanceOutput.distance <= 0.0 {
            // Failure!
            output.state = b2TOIOutput.State.overlapped
            output.t = 0.0
            break
        }
        
        if distanceOutput.distance < target + tolerance {
            // Victory!
            output.state = b2TOIOutput.State.touching
            output.t = t1
            break
        }
        
        // Initialize the separating axis.
        var fcn = b2SeparationFunction()
        fcn.initialize(cache, proxyA, sweepA, proxyB, sweepB, t1)
#if false
        // Dump the curve seen by the root finder
        let N = 100
        let dx = b2Float(1.0) / b2Float(N)
        var xs = [b2Float](count: N + 1, repeatedValue: 0.0)
        var fs = [b2Float](count: N + 1, repeatedValue: 0.0)
        
        var x: b2Float = 0.0
        
        for i in 0 ... N {
            let xfA = sweepA.GetTransform(x)
            let xfB = sweepB.GetTransform(x)
            let f = fcn.evaluate(xfA, xfB) - target
            
            println("%g %g\n", x, f)
            
            xs[i] = x
            fs[i] = f
            
            x += dx
        }
#endif
        
        // Compute the TOI on the separating axis. We do this by successively
        // resolving the deepest point. This loop is bounded by the number of vertices.
        var done = false
        var t2 = tMax
        var pushBackIter = 0
        while true {
            // Find the deepest point at t2. Store the witness point indices.
            var (s2, indexA, indexB) = fcn.findMinSeparation(t2)
            
            // Is the final configuration separated?
            if s2 > target + tolerance {
                // Victory!
                output.state = b2TOIOutput.State.separated
                output.t = tMax
                done = true
                break
            }
            
            // Has the separation reached tolerance?
            if s2 > target - tolerance {
                // Advance the sweeps
                t1 = t2
                break
            }
            
            // Compute the initial separation of the witness points.
            var s1 = fcn.evaluate(indexA, indexB, t1)
            
            // Check for initial overlap. This might happen if the root finder
            // runs out of iterations.
            if s1 < target - tolerance {
                output.state = b2TOIOutput.State.failed
                output.t = t1
                done = true
                break
            }
            
            // Check for touching
            if s1 <= target + tolerance {
                // Victory! t1 should hold the TOI (could be 0.0).
                output.state = b2TOIOutput.State.touching
                output.t = t1
                done = true
                break
            }
            
            // Compute 1D root of: f(x) - target = 0
            var rootIterCount = 0
            var a1 = t1, a2 = t2
            while true {
                // Use a mix of the secant rule and bisection.
                var t: b2Float
                if rootIterCount & 1 != 0 {
                    // Secant rule to improve convergence.
                    t = a1 + (target - s1) * (a2 - a1) / (s2 - s1)
                }
                else {
                    // Bisection to guarantee progress.
                    t = 0.5 * (a1 + a2)
                }
                
                rootIterCount += 1
                b2_toiRootIters += 1
                
                let s = fcn.evaluate(indexA, indexB, t)
                
                if abs(s - target) < tolerance {
                    // t2 holds a tentative value for t1
                    t2 = t
                    break
                }
                
                // Ensure we continue to bracket the root.
                if s > target {
                    a1 = t
                    s1 = s
                }
                else {
                    a2 = t
                    s2 = s
                }
                
                if rootIterCount == 50 {
                    break
                }
            }
            
            b2_toiMaxRootIters = max(b2_toiMaxRootIters, rootIterCount)
            
            pushBackIter += 1
            
            if pushBackIter == b2_maxPolygonVertices {
                break
            }
        }
        
        iter += 1
        b2_toiIters += 1
        
        if done {
            break
        }
        
        if iter == k_maxIterations {
            // Root finder got stuck. Semi-victory.
            output.state = b2TOIOutput.State.failed
            output.t = t1
            break
        }
    }
    
    b2_toiMaxIters = max(b2_toiMaxIters, iter)
    
    let time = timer.milliseconds
    b2_toiMaxTime = max(b2_toiMaxTime, time)
    b2_toiTime += time
}

/// Internal

public var b2_toiTime: b2Float = 0, b2_toiMaxTime: b2Float = 0
public var b2_toiCalls = 0, b2_toiIters = 0, b2_toiMaxIters = 0
public var b2_toiRootIters = 0, b2_toiMaxRootIters = 0

private struct b2SeparationFunction {
    enum TYPE : CustomStringConvertible {
        case points
        case faceA
        case faceB
        var description: String {
            switch self {
            case .points: return "points"
            case .faceA: return "faceA"
            case .faceB: return "faceB"
            }
        }
    }
    
    // TODO_ERIN might not need to return the separation
    @discardableResult mutating func initialize(_ cache: b2SimplexCache,
                                                _ proxyA: b2DistanceProxy, _ sweepA: b2Sweep,
                                                _ proxyB: b2DistanceProxy, _ sweepB: b2Sweep,
                                                _ t1: b2Float) -> b2Float
    {
        m_proxyA = proxyA
        m_proxyB = proxyB
        let count = cache.count
        assert(0 < count && count < 3)
        
        m_sweepA = sweepA
        m_sweepB = sweepB
        
        let xfA = m_sweepA.getTransform(beta: t1)
        let xfB = m_sweepB.getTransform(beta: t1)
        
        if count == 1 {
            m_type = TYPE.points
            let localPointA = m_proxyA.getVertex(Int(cache.indexA[0]))
            let localPointB = m_proxyB.getVertex(Int(cache.indexB[0]))
            let pointA = b2Mul(xfA, localPointA)
            let pointB = b2Mul(xfB, localPointB)
            m_axis = pointB - pointA
            let s = m_axis.normalize()
            return s
        }
        else if cache.indexA[0] == cache.indexA[1] {
            // Two points on B and one on A.
            m_type = TYPE.faceB
            let localPointB1 = proxyB.getVertex(Int(cache.indexB[0]))
            let localPointB2 = proxyB.getVertex(Int(cache.indexB[1]))
            
            m_axis = b2Cross(localPointB2 - localPointB1, 1.0)
            m_axis.normalize()
            let normal = b2Mul(xfB.q, m_axis)
            
            m_localPoint = 0.5 * (localPointB1 + localPointB2)
            let pointB = b2Mul(xfB, m_localPoint)
            
            let localPointA = proxyA.getVertex(Int(cache.indexA[0]))
            let pointA = b2Mul(xfA, localPointA)
            
            var s = b2Dot(pointA - pointB, normal)
            if s < 0.0 {
                m_axis = -m_axis
                s = -s
            }
            return s
        }
        else {
            // Two points on A and one or two points on B.
            m_type = TYPE.faceA
            let localPointA1 = m_proxyA.getVertex(Int(cache.indexA[0]))
            let localPointA2 = m_proxyA.getVertex(Int(cache.indexA[1]))
            
            m_axis = b2Cross(localPointA2 - localPointA1, 1.0)
            m_axis.normalize()
            let normal = b2Mul(xfA.q, m_axis)
            
            m_localPoint = 0.5 * (localPointA1 + localPointA2)
            let pointA = b2Mul(xfA, m_localPoint)
            
            let localPointB = m_proxyB.getVertex(Int(cache.indexB[0]))
            let pointB = b2Mul(xfB, localPointB)
            
            var s = b2Dot(pointB - pointA, normal)
            if s < 0.0 {
                m_axis = -m_axis
                s = -s
            }
            return s
        }
    }
    
    func findMinSeparation(_ t: b2Float) -> (separation: b2Float, indexA: Int, indexB: Int) {
        var indexA: Int
        var indexB: Int
        
        let xfA = m_sweepA.getTransform(beta: t)
        let xfB = m_sweepB.getTransform(beta: t)
        
        switch m_type {
        case TYPE.points:
            let axisA = b2MulT(xfA.q,  m_axis)
            let axisB = b2MulT(xfB.q, -m_axis)
            
            indexA = m_proxyA.getSupport(axisA)
            indexB = m_proxyB.getSupport(axisB)
            
            let localPointA = m_proxyA.getVertex(indexA)
            let localPointB = m_proxyB.getVertex(indexB)
            
            let pointA = b2Mul(xfA, localPointA)
            let pointB = b2Mul(xfB, localPointB)
            
            let separation = b2Dot(pointB - pointA, m_axis)
            return (separation, indexA, indexB)
            
        case TYPE.faceA:
            let normal = b2Mul(xfA.q, m_axis)
            let pointA = b2Mul(xfA, m_localPoint)
            
            let axisB = b2MulT(xfB.q, -normal)
            
            indexA = -1
            indexB = m_proxyB.getSupport(axisB)
            
            let localPointB = m_proxyB.getVertex(indexB)
            let pointB = b2Mul(xfB, localPointB)
            
            let separation = b2Dot(pointB - pointA, normal)
            return (separation, indexA, indexB)
            
        case TYPE.faceB:
            let normal = b2Mul(xfB.q, m_axis)
            let pointB = b2Mul(xfB, m_localPoint)
            
            let axisA = b2MulT(xfA.q, -normal)
            
            indexB = -1
            indexA = m_proxyA.getSupport(axisA)
            
            let localPointA = m_proxyA.getVertex(indexA)
            let pointA = b2Mul(xfA, localPointA)
            
            let separation = b2Dot(pointA - pointB, normal)
            return (separation, indexA, indexB)
            
            //    default:
            //      assert(false)
            //      indexA = -1
            //      indexB = -1
            //      return (0.0, indexA, indexB)
        }
    }
    
    func evaluate(_ indexA: Int, _ indexB: Int, _ t: b2Float) -> b2Float {
        let xfA = m_sweepA.getTransform(beta: t)
        let xfB = m_sweepB.getTransform(beta: t)
        
        switch m_type {
        case .points:
            let localPointA = m_proxyA.getVertex(indexA)
            let localPointB = m_proxyB.getVertex(indexB)
            
            let pointA = b2Mul(xfA, localPointA)
            let pointB = b2Mul(xfB, localPointB)
            let separation = b2Dot(pointB - pointA, m_axis)
            
            return separation
            
        case .faceA:
            let normal = b2Mul(xfA.q, m_axis)
            let pointA = b2Mul(xfA, m_localPoint)
            
            let localPointB = m_proxyB.getVertex(indexB)
            let pointB = b2Mul(xfB, localPointB)
            
            let separation = b2Dot(pointB - pointA, normal)
            return separation
            
        case .faceB:
            let normal = b2Mul(xfB.q, m_axis)
            let pointB = b2Mul(xfB, m_localPoint)
            
            let localPointA = m_proxyA.getVertex(indexA)
            let pointA = b2Mul(xfA, localPointA)
            
            let separation = b2Dot(pointA - pointB, normal)
            return separation
            
            //    default:
            //      assert(false)
            //      return 0.0
        }
    }
    
    var m_proxyA = b2DistanceProxy()
    var m_proxyB = b2DistanceProxy()
    var m_sweepA = b2Sweep(), m_sweepB = b2Sweep()
    var m_type = TYPE.points
    var m_localPoint = b2Vec2()
    var m_axis = b2Vec2()
}


