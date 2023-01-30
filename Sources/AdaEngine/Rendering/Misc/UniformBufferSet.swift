//
//  UniformBufferSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/31/23.
//

public protocol UniformBufferSet: AnyObject {
    func setBuffer(_ buffer: UniformBuffer, set: Int, frameIndex: Int)
    func getBuffer(binding: Int, set: Int, frameIndex: Int) -> UniformBuffer
    
    func initBuffers(length: Int, binding: Int, set: Int)
}

public extension UniformBufferSet {
    func initBuffers<T>(for: T.Type, count: Int = 1, binding: Int, set: Int) {
        assert(count >= 1, "Count can't be less then 1")
        self.initBuffers(length: MemoryLayout<T>.stride * count, binding: binding, set: set)
    }
}
