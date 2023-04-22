//
//  Sampler.swift
//  
//
//  Created by v.prusakov on 1/22/23.
//

/// Filtering options for determining which pixel value is returned within a mipmap level.
public enum SamplerMigMagFilter: Codable {
    case nearest
    case linear
}

/// Filtering options for determining what pixel value is returned with multiple mipmap levels.
public enum SamplerMipFilter: Codable {
    case nearest
    case linear
    case notMipmapped
}

/// An object that you use to configure a texture sampler.
public struct SamplerDescriptor: Codable {
    
    /// The filtering option for combining pixels within one mipmap level when the sample footprint is larger than a pixel (minification).
    public var minFilter: SamplerMigMagFilter
    
    /// The filtering operation for combining pixels within one mipmap level when the sample footprint is smaller than a pixel (magnification).
    public var magFilter: SamplerMigMagFilter
    
    /// The filtering option for combining pixels between two mipmap levels.
    public var mipFilter: SamplerMipFilter
    
    /// The minimum level of detail (LOD) to use when sampling from a texture.
    public var lodMinClamp: Float
    
    /// The maximum level of detail (LOD) to use when sampling from a texture.
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

/// Sampler representation in GPU. You can create your own sampler instance for manage how to draw texture.
public protocol Sampler: AnyObject {
    
    /// Contains information about sampler descriptor.
    var descriptor: SamplerDescriptor { get }
}
