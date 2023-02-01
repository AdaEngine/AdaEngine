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

public let b2_nullNode = -1

/// A node in the dynamic tree. The client does not interact with this directly.
open class b2TreeNode<T> : CustomStringConvertible {
    /// Enlarged AABB
    open var aabb = b2AABB()
    
    open var userData: T? = nil
    
    var parentOrNext: Int = b2_nullNode
    
    var child1: Int = b2_nullNode
    var child2: Int = b2_nullNode
    
    // leaf = 0, free node = -1
    var height: Int = -1
    
    func IsLeaf() -> Bool {
        return child1 == b2_nullNode
    }
    open var description: String {
        return "{aabb=\(aabb), parentOrNext=\(parentOrNext), child1=\(child1), child2=\(child2), height=\(height)}"
    }
}

/// A dynamic AABB tree broad-phase, inspired by Nathanael Presson's btDbvt.
/// A dynamic tree arranges data in a binary tree to accelerate
/// queries such as volume queries and ray casts. Leafs are proxies
/// with an AABB. In the tree we expand the proxy AABB by b2_fatAABBFactor
/// so that the proxy AABB is bigger than the client object. This allows the client
/// object to move by small amounts without triggering a tree update.
///
/// Nodes are pooled and relocatable, so we use node indices rather than pointers.
open class b2DynamicTree<T> : CustomStringConvertible {
    var m_root: Int
    
    var m_nodes: [b2TreeNode<T>]
    var m_nodeCount: Int
    var m_nodeCapacity: Int
    
    var m_freeList: Int
    
    /// This is used to incrementally traverse the tree for re-balancing.
    //var m_path : UInt
    
    var m_insertionCount: Int
    
    /// Constructing the tree initializes the node pool.
    public init() {
        m_root = b2_nullNode
        
        m_nodeCapacity = 16
        m_nodeCount = 0
        m_nodes = Array<b2TreeNode<T>>()
        m_nodes.reserveCapacity(m_nodeCapacity)
        
        // Build a linked list for the free list.
        for i in 0 ..< m_nodeCapacity - 1 {
            m_nodes.append(b2TreeNode())
            m_nodes.last!.parentOrNext = i + 1
            m_nodes.last!.height = -1
        }
        m_nodes.append(b2TreeNode())
        m_nodes.last!.parentOrNext = b2_nullNode
        m_nodes.last!.height = -1
        m_freeList = 0
        
        m_insertionCount = 0
    }
    
    /// Destroy the tree, freeing the node pool.
    deinit {
    }
    
    /// Create a proxy. Provide a tight fitting AABB and a userData pointer.
    open func createProxy(aabb: b2AABB, userData: T?) -> Int {
        let proxyId = allocateNode()
        
        // Fatten the aabb.
        let r = b2Vec2(b2_aabbExtension, b2_aabbExtension)
        m_nodes[proxyId].aabb.lowerBound = aabb.lowerBound - r
        m_nodes[proxyId].aabb.upperBound = aabb.upperBound + r
        m_nodes[proxyId].userData = userData
        m_nodes[proxyId].height = 0
        
        insertLeaf(proxyId)
        
        return proxyId
    }
    
    /// Destroy a proxy. This asserts if the id is invalid.
    open func destroyProxy(_ proxyId: Int) {
        assert(0 <= proxyId && proxyId < m_nodes.count)
        assert(m_nodes[proxyId].IsLeaf())
        
        removeLeaf(proxyId)
        freeNode(proxyId)
    }
    
    /**
     Move a proxy with a swepted AABB. If the proxy has moved outside of its fattened AABB,
     then the proxy is removed from the tree and re-inserted. Otherwise
     the function returns immediately.
     
     - returns: true if the proxy was re-inserted.
     */
    open func moveProxy(_ proxyId: Int, aabb: b2AABB, displacement: b2Vec2) -> Bool {
        assert(0 <= proxyId && proxyId < m_nodes.count)
        
        assert(m_nodes[proxyId].IsLeaf())
        
        if m_nodes[proxyId].aabb.contains(aabb) {
            return false
        }
        
        removeLeaf(proxyId)
        
        // Extend AABB.
        var b = aabb
        let r = b2Vec2(b2_aabbExtension, b2_aabbExtension)
        b.lowerBound = b.lowerBound - r
        b.upperBound = b.upperBound + r
        
        // Predict AABB displacement.
        let d = b2_aabbMultiplier * displacement
        
        if d.x < 0.0 {
            b.lowerBound.x += d.x
        }
        else {
            b.upperBound.x += d.x
        }
        
        if d.y < 0.0 {
            b.lowerBound.y += d.y
        }
        else {
            b.upperBound.y += d.y
        }
        
        m_nodes[proxyId].aabb = b
        
        insertLeaf(proxyId)
        return true
    }
    
    /**
     Get proxy user data.
     
     - returns: the proxy user data or 0 if the id is invalid.
     */
    open func getUserData(_ proxyId: Int) -> T? {
        assert(0 <= proxyId && proxyId < m_nodes.count)
        return m_nodes[proxyId].userData
    }
    
    /// Get the fat AABB for a proxy.
    open func getFatAABB(_ proxyId: Int) -> b2AABB {
        assert(0 <= proxyId && proxyId < m_nodes.count)
        return m_nodes[proxyId].aabb
    }
    
    /// Query an AABB for overlapping proxies. The callback class
    /// is called for each proxy that overlaps the supplied AABB.
    open func query<T: b2QueryWrapper>(callback: T, aabb: b2AABB) {
        var stack = b2GrowableStack<Int>(capacity: 256)
        stack.push(m_root)
        
        while (stack.count > 0) {
            let nodeId = stack.pop()
            if nodeId == b2_nullNode {
                continue
            }
            
            let node = m_nodes[nodeId]
            
            if b2TestOverlap(node.aabb, aabb) {
                if node.IsLeaf() {
                    let proceed = callback.queryCallback(nodeId)
                    if proceed == false {
                        return
                    }
                }
                else {
                    stack.push(node.child1)
                    stack.push(node.child2)
                }
            }
        }
    }
    
    /// Ray-cast against the proxies in the tree. This relies on the callback
    /// to perform a exact ray-cast in the case were the proxy contains a shape.
    /// The callback also performs the any collision filtering. This has performance
    /// roughly equal to k * log(n), where k is the number of collisions and n is the
    /// number of proxies in the tree.
    /// @param input the ray-cast input data. The ray extends from p1 to p1 + maxFraction * (p2 - p1).
    /// @param callback a callback class that is called for each proxy that is hit by the ray.
    open func rayCast<T: b2RayCastWrapper>(callback: T, input: b2RayCastInput) {
        let p1 = input.p1
        let p2 = input.p2
        var r = p2 - p1
        assert(r.lengthSquared() > 0.0)
        r.normalize()
        
        // v is perpendicular to the segment.
        let v = b2Cross(1.0, r)
        let abs_v = b2Abs(v)
        
        // Separating axis for segment (Gino, p80).
        // |dot(v, p1 - c)| > dot(|v|, h)
        
        var maxFraction = input.maxFraction
        
        // Build a bounding box for the segment.
        var segmentAABB = b2AABB()
        let t = p1 + maxFraction * (p2 - p1)
        segmentAABB.lowerBound = b2Min(p1, t)
        segmentAABB.upperBound = b2Max(p1, t)
        
        
        var stack = b2GrowableStack<Int>(capacity: 256)
        stack.push(m_root)
        
        while stack.count > 0 {
            let nodeId = stack.pop()
            if nodeId == b2_nullNode {
                continue
            }
            
            let node = m_nodes[nodeId]
            
            if b2TestOverlap(node.aabb, segmentAABB) == false {
                continue
            }
            
            // Separating axis for segment (Gino, p80).
            // |dot(v, p1 - c)| > dot(|v|, h)
            let c = node.aabb.center
            let h = node.aabb.extents
            let separation = abs(b2Dot(v, p1 - c)) - b2Dot(abs_v, h)
            if separation > 0.0 {
                continue
            }
            
            if node.IsLeaf() {
                var subInput = b2RayCastInput()
                subInput.p1 = input.p1
                subInput.p2 = input.p2
                subInput.maxFraction = maxFraction
                
                let value = callback.rayCastCallback(subInput, nodeId)
                
                if value == 0.0 {
                    // The client has terminated the ray cast.
                    return
                }
                
                if value > 0.0 {
                    // Update segment bounding box.
                    maxFraction = value
                    let t = p1 + maxFraction * (p2 - p1)
                    segmentAABB.lowerBound = b2Min(p1, t)
                    segmentAABB.upperBound = b2Max(p1, t)
                }
            }
            else {
                stack.push(node.child1)
                stack.push(node.child2)
            }
        }
    }
    
    /// Validate this tree. For testing.
    open func validate() {
        validateStructure(m_root)
        validateMetrics(m_root)
        
        var freeCount = 0
        var freeIndex = m_freeList
        while freeIndex != b2_nullNode {
            assert(0 <= freeIndex && freeIndex < m_nodes.count)
            freeIndex = m_nodes[freeIndex].parentOrNext
            freeCount += 1
        }
        assert(getHeight() == computeHeight())
        //assert(m_nodeCount + freeCount == m_nodes.count)
    }
    
    /// Compute the height of the binary tree in O(N) time. Should not be
    /// called often.
    open func getHeight() -> Int {
        if m_root == b2_nullNode {
            return 0
        }
        return m_nodes[m_root].height
    }
    
    /// Get the maximum balance of an node in the tree. The balance is the difference
    /// in height of the two children of a node.
    open func getMaxBalance() -> Int {
        var maxBalance = 0
        for i in 0 ..< m_nodes.count {
            let node = m_nodes[i]
            if node.height <= 1 {
                continue
            }
            
            assert(node.IsLeaf() == false)
            
            let child1 = node.child1
            let child2 = node.child2
            let balance = abs(m_nodes[child2].height - m_nodes[child1].height)
            maxBalance = max(maxBalance, balance)
        }
        return maxBalance
    }
    
    /// Get the ratio of the sum of the node areas to the root area.
    open func getAreaRatio() -> b2Float {
        if m_root == b2_nullNode {
            return 0.0
        }
        
        let root = m_nodes[m_root]
        let rootArea = root.aabb.perimeter
        
        var totalArea: b2Float = 0.0
        for i in 0 ..< m_nodes.count {
            let node = m_nodes[i]
            if node.height < 0 {
                // Free node in pool
                continue
            }
            
            totalArea += node.aabb.perimeter
        }
        
        return totalArea / rootArea
    }
    
    /// Build an optimal tree. Very expensive. For testing.
    open func rebuildBottomUp() {
        var nodes = [Int](repeating: 0, count: m_nodes.count)
        //int32* nodes = (int32*)b2Alloc(m_nodeCount * sizeof(int32))
        var count = 0
        
        // Build array of leaves. Free the rest.
        for i in 0 ..< m_nodes.count {
            if m_nodes[i].height < 0 {
                // free node in pool
                continue
            }
            
            if m_nodes[i].IsLeaf() {
                m_nodes[i].parentOrNext = b2_nullNode
                nodes[count] = i
                count += 1
            }
            else {
                freeNode(i)
            }
        }
        
        while count > 1 {
            var minCost = b2_maxFloat
            var iMin = -1, jMin = -1
            for i in 0 ..< count {
                let aabbi = m_nodes[nodes[i]].aabb
                
                for j in i + 1 ..< count {
                    let aabbj = m_nodes[nodes[j]].aabb
                    var b = b2AABB()
                    b.combine(aabbi, aabbj)
                    let cost = b.perimeter
                    if cost < minCost {
                        iMin = i
                        jMin = j
                        minCost = cost
                    }
                }
            }
            
            let index1 = nodes[iMin]
            let index2 = nodes[jMin]
            let child1 = m_nodes[index1]
            let child2 = m_nodes[index2]
            
            let parentIndex = allocateNode()
            let parent = m_nodes[parentIndex]
            parent.child1 = index1
            parent.child2 = index2
            parent.height = 1 + max(child1.height, child2.height)
            parent.aabb.combine(child1.aabb, child2.aabb)
            parent.parentOrNext = b2_nullNode
            
            child1.parentOrNext = parentIndex
            child2.parentOrNext = parentIndex
            
            nodes[jMin] = nodes[count-1]
            nodes[iMin] = parentIndex
            count -= 1
        }
        
        m_root = nodes[0]
        //    b2Free(nodes)
        
        validate()
    }
    
    /// Shift the world origin. Useful for large worlds.
    /// The shift formula is: position -= newOrigin
    /// @param newOrigin the new origin with respect to the old origin
    open func shiftOrigin(_ newOrigin: b2Vec2) {
        // Build array of leaves. Free the rest.
        for i in 0 ..< m_nodes.count {
            m_nodes[i].aabb.lowerBound -= newOrigin
            m_nodes[i].aabb.upperBound -= newOrigin
        }
    }
    
    fileprivate func allocateNode() -> Int {
        if m_freeList == b2_nullNode {
            let node = b2TreeNode<T>()
            node.parentOrNext = b2_nullNode
            node.height = -1
            m_nodes.append(node)
            m_freeList = m_nodes.count - 1
        }
        
        let nodeId = m_freeList
        m_freeList = m_nodes[nodeId].parentOrNext
        m_nodes[nodeId].parentOrNext = b2_nullNode
        m_nodes[nodeId].child1 = b2_nullNode
        m_nodes[nodeId].child2 = b2_nullNode
        m_nodes[nodeId].height = 0
        m_nodes[nodeId].userData = nil
        return nodeId
    }
    func freeNode(_ nodeId: Int) {
        assert(0 <= nodeId && nodeId < m_nodes.count)
        assert(0 < m_nodes.count)
        m_nodes[nodeId].parentOrNext = m_freeList
        m_nodes[nodeId].height = -1
        m_freeList = nodeId
    }
    
    func insertLeaf(_ leaf: Int) {
        m_insertionCount += 1
        
        if m_root == b2_nullNode {
            m_root = leaf
            m_nodes[m_root].parentOrNext = b2_nullNode
            return
        }
        
        // Find the best sibling for this node
        let leafAABB = m_nodes[leaf].aabb
        var index = m_root
        while m_nodes[index].IsLeaf() == false {
            let child1 = m_nodes[index].child1
            let child2 = m_nodes[index].child2
            
            let area = m_nodes[index].aabb.perimeter
            
            var combinedAABB = b2AABB()
            combinedAABB.combine(m_nodes[index].aabb, leafAABB)
            let combinedArea = combinedAABB.perimeter
            
            // Cost of creating a new parent for this node and the new leaf
            let cost = 2.0 * combinedArea
            
            // Minimum cost of pushing the leaf further down the tree
            let inheritanceCost = 2.0 * (combinedArea - area)
            
            // Cost of descending into child1
            var cost1: b2Float
            if m_nodes[child1].IsLeaf() {
                var aabb = b2AABB()
                aabb.combine(leafAABB, m_nodes[child1].aabb)
                cost1 = aabb.perimeter + inheritanceCost
            }
            else {
                var aabb = b2AABB()
                aabb.combine(leafAABB, m_nodes[child1].aabb)
                let oldArea = m_nodes[child1].aabb.perimeter
                let newArea = aabb.perimeter
                cost1 = (newArea - oldArea) + inheritanceCost
            }
            
            // Cost of descending into child2
            var cost2: b2Float
            if m_nodes[child2].IsLeaf() {
                var aabb = b2AABB()
                aabb.combine(leafAABB, m_nodes[child2].aabb)
                cost2 = aabb.perimeter + inheritanceCost
            }
            else {
                var aabb = b2AABB()
                aabb.combine(leafAABB, m_nodes[child2].aabb)
                let oldArea = m_nodes[child2].aabb.perimeter
                let newArea = aabb.perimeter
                cost2 = newArea - oldArea + inheritanceCost
            }
            
            // Descend according to the minimum cost.
            if cost < cost1 && cost < cost2 {
                break
            }
            
            // Descend
            if cost1 < cost2 {
                index = child1
            }
            else {
                index = child2
            }
        }
        
        let sibling = index
        
        // Create a new parent.
        let oldParent = m_nodes[sibling].parentOrNext
        let newParent = allocateNode()
        m_nodes[newParent].parentOrNext = oldParent
        m_nodes[newParent].userData = nil
        m_nodes[newParent].aabb.combine(leafAABB, m_nodes[sibling].aabb)
        m_nodes[newParent].height = m_nodes[sibling].height + 1
        
        if oldParent != b2_nullNode {
            // The sibling was not the root.
            if m_nodes[oldParent].child1 == sibling {
                m_nodes[oldParent].child1 = newParent
            }
            else {
                m_nodes[oldParent].child2 = newParent
            }
            
            m_nodes[newParent].child1 = sibling
            m_nodes[newParent].child2 = leaf
            m_nodes[sibling].parentOrNext = newParent
            m_nodes[leaf].parentOrNext = newParent
        }
        else {
            // The sibling was the root.
            m_nodes[newParent].child1 = sibling
            m_nodes[newParent].child2 = leaf
            m_nodes[sibling].parentOrNext = newParent
            m_nodes[leaf].parentOrNext = newParent
            m_root = newParent
        }
        
        // Walk back up the tree fixing heights and AABBs
        index = m_nodes[leaf].parentOrNext
        while index != b2_nullNode {
            index = balance(index)
            
            let child1 = m_nodes[index].child1
            let child2 = m_nodes[index].child2
            
            assert(child1 != b2_nullNode)
            assert(child2 != b2_nullNode)
            
            m_nodes[index].height = 1 + max(m_nodes[child1].height, m_nodes[child2].height)
            m_nodes[index].aabb.combine(m_nodes[child1].aabb, m_nodes[child2].aabb)
            
            index = m_nodes[index].parentOrNext
        }
        
        //Validate()
    }
    func removeLeaf(_ leaf: Int) {
        if leaf == m_root {
            m_root = b2_nullNode
            return
        }
        
        let parent = m_nodes[leaf].parentOrNext
        let grandParent = m_nodes[parent].parentOrNext
        var sibling: Int
        if m_nodes[parent].child1 == leaf {
            sibling = m_nodes[parent].child2
        }
        else {
            sibling = m_nodes[parent].child1
        }
        
        if grandParent != b2_nullNode {
            // Destroy parent and connect sibling to grandParent.
            if m_nodes[grandParent].child1 == parent {
                m_nodes[grandParent].child1 = sibling
            }
            else {
                m_nodes[grandParent].child2 = sibling
            }
            m_nodes[sibling].parentOrNext = grandParent
            freeNode(parent)
            
            // Adjust ancestor bounds.
            var index = grandParent
            while index != b2_nullNode {
                index = balance(index)
                
                let child1 = m_nodes[index].child1
                let child2 = m_nodes[index].child2
                
                m_nodes[index].aabb.combine(m_nodes[child1].aabb, m_nodes[child2].aabb)
                m_nodes[index].height = 1 + max(m_nodes[child1].height, m_nodes[child2].height)
                
                index = m_nodes[index].parentOrNext
            }
        }
        else {
            m_root = sibling
            m_nodes[sibling].parentOrNext = b2_nullNode
            freeNode(parent)
        }
        
        //Validate()
    }
    
    // Perform a left or right rotation if node A is imbalanced.
    // Returns the new root index.
    func balance(_ iA : Int) -> Int {
        assert(iA != b2_nullNode)
        
        let A = m_nodes[iA]
        if A.IsLeaf() || A.height < 2 {
            return iA
        }
        
        let iB = A.child1
        let iC = A.child2
        assert(0 <= iB && iB < m_nodes.count)
        assert(0 <= iC && iC < m_nodes.count)
        
        let B = m_nodes[iB]
        let C = m_nodes[iC]
        
        let balance = C.height - B.height
        
        // Rotate C up
        if balance > 1 {
            let iF = C.child1
            let iG = C.child2
            let F = m_nodes[iF]
            let G = m_nodes[iG]
            assert(0 <= iF && iF < m_nodes.count)
            assert(0 <= iG && iG < m_nodes.count)
            
            // Swap A and C
            C.child1 = iA
            C.parentOrNext = A.parentOrNext
            A.parentOrNext = iC
            
            // A's old parent should point to C
            if C.parentOrNext != b2_nullNode {
                if m_nodes[C.parentOrNext].child1 == iA {
                    m_nodes[C.parentOrNext].child1 = iC
                }
                else {
                    assert(m_nodes[C.parentOrNext].child2 == iA)
                    m_nodes[C.parentOrNext].child2 = iC
                }
            }
            else {
                m_root = iC
            }
            
            // Rotate
            if F.height > G.height {
                C.child2 = iF
                A.child2 = iG
                G.parentOrNext = iA
                A.aabb.combine(B.aabb, G.aabb)
                C.aabb.combine(A.aabb, F.aabb)
                
                A.height = 1 + max(B.height, G.height)
                C.height = 1 + max(A.height, F.height)
            }
            else {
                C.child2 = iG
                A.child2 = iF
                F.parentOrNext = iA
                A.aabb.combine(B.aabb, F.aabb)
                C.aabb.combine(A.aabb, G.aabb)
                
                A.height = 1 + max(B.height, F.height)
                C.height = 1 + max(A.height, G.height)
            }
            
            return iC
        }
        
        // Rotate B up
        if balance < -1 {
            let iD = B.child1
            let iE = B.child2
            let D = m_nodes[iD]
            let E = m_nodes[iE]
            assert(0 <= iD && iD < m_nodes.count)
            assert(0 <= iE && iE < m_nodes.count)
            
            // Swap A and B
            B.child1 = iA
            B.parentOrNext = A.parentOrNext
            A.parentOrNext = iB
            
            // A's old parent should point to B
            if B.parentOrNext != b2_nullNode {
                if m_nodes[B.parentOrNext].child1 == iA {
                    m_nodes[B.parentOrNext].child1 = iB
                }
                else {
                    assert(m_nodes[B.parentOrNext].child2 == iA)
                    m_nodes[B.parentOrNext].child2 = iB
                }
            }
            else {
                m_root = iB
            }
            
            // Rotate
            if D.height > E.height {
                B.child2 = iD
                A.child1 = iE
                E.parentOrNext = iA
                A.aabb.combine(C.aabb, E.aabb)
                B.aabb.combine(A.aabb, D.aabb)
                
                A.height = 1 + max(C.height, E.height)
                B.height = 1 + max(A.height, D.height)
            }
            else {
                B.child2 = iE
                A.child1 = iD
                D.parentOrNext = iA
                A.aabb.combine(C.aabb, D.aabb)
                B.aabb.combine(A.aabb, E.aabb)
                
                A.height = 1 + max(C.height, D.height)
                B.height = 1 + max(A.height, E.height)
            }
            
            return iB
        }
        
        return iA
    }
    
    func computeHeight() -> Int {
        let height = computeHeight(m_root)
        return height
    }
    
    // Compute the height of a sub-tree.
    func computeHeight(_ nodeId : Int) -> Int {
        assert(0 <= nodeId && nodeId < m_nodes.count)
        let node = m_nodes[nodeId]
        
        if node.IsLeaf() {
            return 0
        }
        
        let height1 = computeHeight(node.child1)
        let height2 = computeHeight(node.child2)
        return 1 + max(height1, height2)
    }
    
    func validateStructure(_ index : Int) {
        if index == b2_nullNode {
            return
        }
        
        if index == m_root {
            assert(m_nodes[index].parentOrNext == b2_nullNode)
        }
        
        let node = m_nodes[index]
        
        let child1 = node.child1
        let child2 = node.child2
        
        if node.IsLeaf() {
            assert(child1 == b2_nullNode)
            assert(child2 == b2_nullNode)
            assert(node.height == 0)
            return
        }
        
        assert(0 <= child1 && child1 < m_nodes.count)
        assert(0 <= child2 && child2 < m_nodes.count)
        
        assert(m_nodes[child1].parentOrNext == index)
        assert(m_nodes[child2].parentOrNext == index)
        
        validateStructure(child1)
        validateStructure(child2)
    }
    
    func validateMetrics(_ index : Int) {
        if index == b2_nullNode {
            return
        }
        
        let node = m_nodes[index]
        
        let child1 = node.child1
        let child2 = node.child2
        
        if node.IsLeaf() {
            assert(child1 == b2_nullNode)
            assert(child2 == b2_nullNode)
            assert(node.height == 0)
            return
        }
        
        assert(0 <= child1 && child1 < m_nodes.count)
        assert(0 <= child2 && child2 < m_nodes.count)
        
        let height1 = m_nodes[child1].height
        let height2 = m_nodes[child2].height
        let height = 1 + max(height1, height2)
        assert(node.height == height)
        
        var aabb = b2AABB()
        aabb.combine(m_nodes[child1].aabb, m_nodes[child2].aabb)
        
        assert(aabb.lowerBound == node.aabb.lowerBound)
        assert(aabb.upperBound == node.aabb.upperBound)
        
        validateMetrics(child1)
        validateMetrics(child2)
    }
    
    open var description: String {
        return "b2DynamicTree[root=\(m_root), nodes=\(m_nodes)]"
    }
}
