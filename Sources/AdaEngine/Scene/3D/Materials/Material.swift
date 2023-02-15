//
//  Material.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public class Material: Resource {
    public required init(asset decoder: AssetDecoder) throws {
        fatalError()
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalError()
    }
    
    public static var resourceType: ResourceType = .material
    public var resourcePath: String = ""
    public var resourceName: String = ""
    
    init(shader: Shader) {
        
    }
    
}

class ShaderMaterial {
    
    init() {
        
    }
    
}
