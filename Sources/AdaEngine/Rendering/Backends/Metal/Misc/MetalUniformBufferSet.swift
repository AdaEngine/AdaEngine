//
//  MetalUniformBufferSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/31/23.
//

#if METAL
import MetalKit

class MetalUniformBufferSet: UniformBufferSet {
    
    /// Max frames in flight.
    let frames: Int
    let backend: RenderBackend
    
    typealias FrameIndex = Int
    typealias Set = Int
    typealias Binding = Int
    
    private var uniformBuffers: [FrameIndex : [Set : [ Binding : UniformBuffer] ] ] = [:]
    
    init(frames: Int, backend: RenderBackend) {
        self.frames = frames
        self.backend = backend
    }
    
    func initBuffers(length: Int, binding: Int, set: Int) {
        for frame in 0 ..< frames {
            let buffer = self.backend.makeUniformBuffer(length: length, binding: binding)
            self.setBuffer(buffer, set: set, frameIndex: frame)
        }
    }
    
    func setBuffer(_ buffer: UniformBuffer, set: Int, frameIndex: Int) {
        // frame -> set -> binding -> buffer
        self.uniformBuffers[frameIndex, default: [:]][set, default: [:]][buffer.binding] = buffer
    }
    
    func getBuffer(binding: Int, set: Int, frameIndex: Int) -> UniformBuffer {
        assert(self.uniformBuffers[frameIndex] != nil)
        assert(self.uniformBuffers[frameIndex]?[set] != nil)
        assert(self.uniformBuffers[frameIndex]?[set]?[binding] != nil)
        return self.uniformBuffers[frameIndex]![set]![binding]!
    }
}

#endif
