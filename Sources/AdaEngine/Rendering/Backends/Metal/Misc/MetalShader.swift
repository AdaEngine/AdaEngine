//
//  MetalShader.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/18/23.
//

#if METAL

import MetalKit

final class MetalShader: CompiledShader {
    let name: String
    
    let library: MTLLibrary
    let function: MTLFunction
    
    init(
        name: String,
        library: MTLLibrary,
        function: MTLFunction
    ) {
        self.name = name
        self.library = library
        self.function = function
    }
}

#endif
