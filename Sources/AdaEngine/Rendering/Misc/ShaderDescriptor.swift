//
//  ShaderDescriptor.swift
//  
//
//  Created by v.prusakov on 5/31/22.
//

/// The base struct describing shader.
public struct ShaderDescriptor {
    
    public let shaderName: String
    
    public enum FunctionType {
        case vertex
        case fragment
        case compute
    }
    
    public struct Function {
        public let entry: String
        public let type: FunctionType
        
        public init(entry: String, type: FunctionType) {
            self.entry = entry
            self.type = type
        }
    }
    
    public let functions: [Function]

    public init(
        shaderName: String,
        vertexFunction: String,
        fragmentFunction: String
    ) {
        self.shaderName = shaderName
        self.functions = [Function(entry: vertexFunction, type: .vertex), Function(entry: fragmentFunction, type: .fragment)]
    }
    
}

public protocol ShaderModule {
    
}
