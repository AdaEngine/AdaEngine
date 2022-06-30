//
//  Image.swift
//  
//
//  Created by v.prusakov on 6/28/22.
//

import Foundation

/// Represent Image object.
public final class Image {
    
    public private(set) var data: Data
    
    public private(set) var height: Int
    public private(set) var width: Int
    
    public private(set) var format: Format
    
    /// Create an empty image.
    public init() {
        self.data = Data()
        self.height = 1
        self.width = 1
        self.format = .rgba8
    }
    
    /// Create an empty image with given height and width.
    public init(width: Int, height: Int, data: Data? = nil, format: Format = .rgba8) {
        assert(width > 0, "Width must be greater than 0.")
        assert(height > 0, "Height must be greater than 0.")
        
        self.data = data ?? Data()
        self.width = width
        self.height = height
        self.format = format
    }

    public required init(assetFrom data: Data) async throws {
        fatalError()
    }
}

public extension Image {
    enum Format: UInt16 {
        case rgba8
        case rgb8
        case bgra8
        case gray
    }
}

public extension Image {
    
    private enum LoadingError: LocalizedError {
        case formatNotSupported(String)
        
        var errorDescription: String? {
            switch self {
            case .formatNotSupported(let format):
                return "Image with format \"\(format)\" not supported."
            }
        }
    }
    
    private static var loaders: [ImageLoaderStrategy] = [
        PNGImageSerializer()
    ]
    
    convenience init(contentsOf file: URL) async throws {
        guard let loader = Self.loaders.first(where: { $0.canDecodeImage(with: file.pathExtension) }) else {
            throw LoadingError.formatNotSupported(file.pathExtension)
        }
        
        let image: Image = try await withCheckedThrowingContinuation { continuation in
            do {
                let data = try Data(contentsOf: file, options: .uncached)
                let image = try loader.decodeImage(from: data)
                continuation.resume(returning: image)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        
        self.init(
            width: image.width,
            height: image.height,
            data: image.data,
            format: image.format
        )
    }
    
}

extension Image: Resource {
//
//    struct ImageAssetRepresentation: Codable {
//        let format: Image.Format
//        let image: Data
//    }
    
    public func encodeContents() async throws -> Data {
        fatalError()
    }
}
