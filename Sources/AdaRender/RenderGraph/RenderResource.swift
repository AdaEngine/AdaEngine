//
//  RenderResource.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/18/23.
//

import AdaECS

public enum RenderResource: Sendable {
    case texture(Texture)
    case buffer(Buffer)
    case sampler(Sampler)
    case entity(Entity)
}

public enum RenderResourceKind: Sendable {
    case texture
    case buffer
    case sampler
    case entity
}

public extension RenderResource {
    var resourceKind: RenderResourceKind {
        switch self {
        case .texture:
            return .texture
        case .buffer:
            return .buffer
        case .sampler:
            return .sampler
        case .entity:
            return .entity
        }
    }
    
    var texture: Texture? {
        guard case .texture(let texture) = self else {
            return nil
        }
        
        return texture
    }
    
    var buffer: Buffer? {
        guard case .buffer(let buffer) = self else {
            return nil
        }
        
        return buffer
    }
    
    var sampler: Sampler? {
        guard case .sampler(let sampler) = self else {
            return nil
        }
        
        return sampler
    }
    
    var entity: Entity? {
        guard case .entity(let entity) = self else {
            return nil
        }
        
        return entity
    }
}
