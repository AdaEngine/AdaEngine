//
//  GenericUniformBufferSet.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/18/24.
//

final class GenericUniformBufferSet: UniformBufferSet {
    /// Max frames in flight.
    let frames: Int
    let device: RenderingDevice

    public var label: String?

    typealias FrameIndex = Int
    typealias Set = Int
    typealias Binding = Int

    private var uniformBuffers: [FrameIndex : [Set : [ Binding : UniformBuffer] ] ] = [:]
    
    init(frames: Int, device: RenderingDevice) {
        self.frames = frames
        self.device = device
    }

    func initBuffers(length: Int, binding: Int, set: Int) {
        for frame in 0 ..< frames {
            let buffer = self.device.createUniformBuffer(length: length, binding: binding)
            buffer.label = self.label
            self._setBuffer(buffer, set: set, frameIndex: frame)
        }
    }
    
    func setBuffer(_ buffer: UniformBuffer, set: Int) {
        self._setBuffer(buffer, set: set, frameIndex: RenderEngine.shared.currentFrameIndex)
    }

    private func _setBuffer(_ buffer: UniformBuffer, set: Int, frameIndex: Int) {
        // frame -> set -> binding -> buffer
        self.uniformBuffers[frameIndex, default: [:]][set, default: [:]][buffer.binding] = buffer
    }

    func getBuffer(binding: Int, set: Int) -> UniformBuffer {
        let frameIndex = RenderEngine.shared.currentFrameIndex
        assert(self.uniformBuffers[frameIndex] != nil)
        assert(self.uniformBuffers[frameIndex]?[set] != nil)
        assert(self.uniformBuffers[frameIndex]?[set]?[binding] != nil)
        return self.uniformBuffers[frameIndex]![set]![binding]!
    }
}