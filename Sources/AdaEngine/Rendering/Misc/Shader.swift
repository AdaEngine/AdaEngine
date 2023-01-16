//
//  Shader.swift
//  
//
//  Created by v.prusakov on 11/4/21.
//

public protocol Shader: AnyObject {
    var name: String { get }
}

#if METAL

import MetalKit

class MetalShader: Shader {
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
