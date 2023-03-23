//
//  MetalVertexBuffer.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/31/23.
//

#if METAL
import MetalKit

class MetalVertexBuffer: MetalBuffer, VertexBuffer {
    
    var binding: Int
    let offset: Int
    
    init(buffer: MTLBuffer, binding: Int, offset: Int) {
        self.binding = binding
        self.offset = offset
        super.init(buffer: buffer)
    }
}

#endif
