//
//  Sampler.swift
//  
//
//  Created by v.prusakov on 1/22/23.
//

public enum SamplerMigMagFilter: Codable {
    case nearest
    case linear
}

public enum SamplerMipFilter: Codable {
    case nearest
    case linear
    case notMipmapped
}

public struct SamplerDescriptor: Codable {
    public var minFilter: SamplerMigMagFilter
    public var magFilter: SamplerMigMagFilter
    public var mipFilter: SamplerMipFilter
    
    public var lodMinClamp: Float
    public var lodMaxClamp: Float
    
    public init(
        minFilter: SamplerMigMagFilter = .nearest,
        magFilter: SamplerMigMagFilter = .nearest,
        mipFilter: SamplerMipFilter = .nearest,
        lodMinClamp: Float = 0,
        lodMaxClamp: Float = .greatestFiniteMagnitude
    ) {
        self.minFilter = minFilter
        self.magFilter = magFilter
        self.mipFilter = mipFilter
        self.lodMinClamp = lodMinClamp
        self.lodMaxClamp = lodMaxClamp
    }
}

public protocol Sampler: AnyObject {
    var descriptor: SamplerDescriptor { get }
}
