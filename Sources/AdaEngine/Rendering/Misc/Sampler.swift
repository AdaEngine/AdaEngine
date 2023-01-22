//
//  Sampler.swift
//  
//
//  Created by v.prusakov on 1/22/23.
//

public enum SamplerMigMagFilter {
    case nearest
    case linear
}

public enum SamplerMipFilter {
    case nearest
    case linear
    case notMipmapped
}

//sampler.maxAnisotropy         = 1
//sampler.sAddressMode          = MTLSamplerAddressMode.clampToEdge
//sampler.tAddressMode          = MTLSamplerAddressMode.clampToEdge
//sampler.rAddressMode          = MTLSamplerAddressMode.clampToEdge
//sampler.normalizedCoordinates = true

public struct SamplerDescriptor {
    public var minFilter: SamplerMigMagFilter = .nearest
    public var magFilter: SamplerMigMagFilter = .nearest
    public var mipFilter: SamplerMipFilter = .nearest
    
    public var lodMinClamp: Float = 0
    public var lodMaxClamp: Float = .greatestFiniteMagnitude
}

public protocol Sampler: AnyObject {
    var descriptor: SamplerDescriptor { get }
}
