//
//  MetalShader.swift
//  
//
//  Created by v.prusakov on 1/18/23.
//

#if METAL

import MetalKit

final class MetalShader: Shader {
    let name: String
    
    let library: MTLLibrary
    let vertexFunction: MTLFunction
    let fragmentFunction: MTLFunction
    
    init(name: String, library: MTLLibrary, vertexFunction: MTLFunction, fragmentFunction: MTLFunction) {
        self.name = name
        self.library = library
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
    }
}

#endif
