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
    let functions: [MTLFunction]
    
    init(name: String, library: MTLLibrary, functions: [MTLFunction]) {
        self.name = name
        self.library = library
        self.functions = functions
    }
}

#endif
