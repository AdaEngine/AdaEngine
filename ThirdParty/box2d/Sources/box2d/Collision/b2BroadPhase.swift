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

public struct b2Pair : CustomStringConvertible {
    public var proxyIdA: Int = -1
    public var proxyIdB: Int = -1
    
    public var description: String {
        return "{\(proxyIdA):\(proxyIdB)}"
    }
}

// MARK: -
/// The broad-phase is used for computing pairs and performing volume queries and ray casts.
/// This broad-phase does not persist pairs. Instead, this reports potentially new pairs.
/// It is up to the client to consume the new pairs and to track subsequent overlap.
open class b2BroadPhase : b2QueryWrapper {
    public struct Const {
        public static let nullProxy = -1
    }
    
    // MARK: public methods
    public init() {
        m_proxyCount = 0
        m_pairBuffer = [b2Pair]()
        m_pairBuffer.reserveCapacity(16)
        m_moveBuffer = [Int]()
        m_moveBuffer.reserveCapacity(16)
    }
    
    /// Create a proxy with an initial AABB. Pairs are not reported until
    /// UpdatePairs is called.
    open func createProxy(aabb: b2AABB, userData: b2FixtureProxy) -> Int {
        let proxyId = m_tree.createProxy(aabb: aabb, userData: userData)
        m_proxyCount += 1
        bufferMove(proxyId)
        return proxyId
    }
    
    /// Destroy a proxy. It is up to the client to remove any pairs.
    open func destroyProxy(_ proxyId: Int) {
        unBufferMove(proxyId)
        m_proxyCount -= 1
        m_tree.destroyProxy(proxyId)
    }
    
    /// Call MoveProxy as many times as you like, then when you are done
    /// call UpdatePairs to finalized the proxy pairs (for your time step).
    open func moveProxy(_ proxyId: Int, aabb: b2AABB, displacement: b2Vec2) {
        let buffer = m_tree.moveProxy(proxyId, aabb: aabb, displacement: displacement)
        if buffer {
            bufferMove(proxyId)
        }
    }
    
    /// Call to trigger a re-processing of it's pairs on the next call to UpdatePairs.
    open func touchProxy(_ proxyId: Int) {
        bufferMove(proxyId)
    }
    
    /// Get the fat AABB for a proxy.
    open func getFatAABB(proxyId: Int) -> b2AABB {
        return m_tree.getFatAABB(proxyId)
    }
    
    /// Get user data from a proxy. Returns NULL if the id is invalid.
    open func getUserData(proxyId : Int) -> b2FixtureProxy? {
        return m_tree.getUserData(proxyId)
    }
    
    /// Test overlap of fat AABBs.
    open func testOverlap(proxyIdA : Int, proxyIdB : Int) -> Bool {
        let aabbA = m_tree.getFatAABB(proxyIdA)
        let aabbB = m_tree.getFatAABB(proxyIdB)
        return b2TestOverlap(aabbA, aabbB)
    }
    
    /// Get the number of proxies.
    open func getProxyCount() -> Int {
        return m_proxyCount
    }
    
    /// Update the pairs. This results in pair callbacks. This can only add pairs.
    open func updatePairs<T: b2BroadPhaseWrapper>(callback: T) {
        // Reset pair buffer
        m_pairBuffer.removeAll(keepingCapacity: true)
        
        // Perform tree queries for all moving proxies.
        for i in 0 ..< m_moveBuffer.count {
            m_queryProxyId = m_moveBuffer[i]
            if m_queryProxyId == Const.nullProxy {
                continue
            }
            
            // We have to query the tree with the fat AABB so that
            // we don't fail to create a pair that may touch later.
            let fatAABB = m_tree.getFatAABB(m_queryProxyId)
            // Query tree, create pairs and add them pair buffer.
            m_tree.query(callback: self, aabb: fatAABB)
        }
        
        // Reset move buffer
        m_moveBuffer.removeAll(keepingCapacity: true)
        
        // Sort the pair buffer to expose duplicates.
        m_pairBuffer.sort {
            if $0.proxyIdA < $1.proxyIdA {
                return true
            }
            if $0.proxyIdA == $1.proxyIdA {
                return $0.proxyIdB < $1.proxyIdB
            }
            return false
        }
        
        // Send the pairs back to the client.
        var i = 0
        while i < m_pairBuffer.count {
            let primaryPair = m_pairBuffer[i]
            var userDataA = m_tree.getUserData(primaryPair.proxyIdA)!
            var userDataB = m_tree.getUserData(primaryPair.proxyIdB)!
            
            callback.addPair(&userDataA, &userDataB)
            i += 1
            
            // Skip any duplicate pairs.
            while i < m_pairBuffer.count {
                let pair = m_pairBuffer[i]
                if pair.proxyIdA != primaryPair.proxyIdA || pair.proxyIdB != primaryPair.proxyIdB {
                    break
                }
                i += 1
            }
        }
        
        // Try to keep the tree balanced.
        //m_tree.Rebalance(4)
    }
    
    /// Query an AABB for overlapping proxies. The callback class
    /// is called for each proxy that overlaps the supplied AABB.
    open func query<T: b2QueryWrapper>(callback : T, aabb: b2AABB) {
        m_tree.query(callback: callback, aabb: aabb)
    }
    
    /**
     Ray-cast against the proxies in the tree. This relies on the callback
     to perform a exact ray-cast in the case were the proxy contains a shape.
     The callback also performs the any collision filtering. This has performance
     roughly equal to k * log(n), where k is the number of collisions and n is the
     number of proxies in the tree.
     
     - parameter input: the ray-cast input data. The ray extends from p1 to p1 + maxFraction * (p2 - p1).
     - parameter callback: a callback class that is called for each proxy that is hit by the ray.
     */
    open func rayCast<T: b2RayCastWrapper>(callback: T, input: b2RayCastInput) {
        m_tree.rayCast(callback: callback, input: input)
    }
    
    /// Get the height of the embedded tree.
    open func getTreeHeight() -> Int {
        return m_tree.getHeight()
    }
    
    /// Get the balance of the embedded tree.
    open func getTreeBalance() -> Int {
        return m_tree.getMaxBalance()
    }
    
    /// Get the quality metric of the embedded tree.
    open func getTreeQuality() -> b2Float {
        return m_tree.getAreaRatio()
    }
    
    /**
     Shift the world origin. Useful for large worlds.
     The shift formula is: position -= newOrigin
     
     - parameter newOrigin: the new origin with respect to the old origin
     */
    open func shiftOrigin(_ newOrigin: b2Vec2) {
        m_tree.shiftOrigin(newOrigin)
    }
    
    // MARK: private methods
    func bufferMove(_ proxyId: Int) {
        m_moveBuffer.append(proxyId)
    }
    func unBufferMove(_ proxyId: Int) {
        for i in 0 ..< m_moveBuffer.count {
            if m_moveBuffer[i] == proxyId {
                m_moveBuffer[i] = Const.nullProxy
            }
        }
    }
    // This is called from b2DynamicTree::Query when we are gathering pairs.
    open func queryCallback(_ proxyId: Int) -> Bool {
        // A proxy cannot form a pair with itself.
        if proxyId == m_queryProxyId {
            return true
        }
        
        let pair = b2Pair(proxyIdA: min(proxyId, m_queryProxyId),
                          proxyIdB: max(proxyId, m_queryProxyId))
        m_pairBuffer.append(pair)
        return true
    }
    
    // MARK: private variables
    var m_tree = b2DynamicTree<b2FixtureProxy>()
    var m_proxyCount: Int = 0
    var m_moveBuffer = [Int]()
    var m_pairBuffer = [b2Pair]()
    var m_queryProxyId: Int = 0
    
}
