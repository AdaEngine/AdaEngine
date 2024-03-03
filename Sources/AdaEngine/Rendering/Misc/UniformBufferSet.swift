//
//  UniformBufferSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/31/23.
//

/// This component contains the set of ``UniformBuffer`` by specific binding and set.
public protocol UniformBufferSet: AnyObject {
    
    /// The debug label for all created buffers.
    var label: String? { get set }
    
    /// Set buffer for specific frame index and set.
    func setBuffer(_ buffer: UniformBuffer, set: Int, frameIndex: Int)
    
    /// Get buffer for specific binding, set and frame index.
    func getBuffer(binding: Int, set: Int, frameIndex: Int) -> UniformBuffer
    
    /// Create set of buffers with specific length. Count of buffer depends on ``RenderEngine/Configuration/maxFramesInFlight`` value.
    func initBuffers(length: Int, binding: Int, set: Int)
}

public extension UniformBufferSet {
    func initBuffers<T>(for: T.Type, count: Int = 1, binding: Int, set: Int) {
        assert(count >= 1, "Count can't be less then 1")
        self.initBuffers(length: MemoryLayout<T>.stride * count, binding: binding, set: set)
    }
}
