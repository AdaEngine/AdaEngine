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
    
    /// Create an image with given height and width.
    /// - Parameter width: The image width.
    /// - Parameter height: The image height.
    /// - Parameter data: Data passed to the image, but if you will pass nil, than image with fill with 0.
    /// - Parameter format: The image format. Default value is `Image.Format.rgba8`
    public init(width: Int, height: Int, data: Data? = nil, format: Format = .rgba8) {
        assert(width > 0, "Width must be greater than 0.")
        assert(height > 0, "Height must be greater than 0.")
        
        self.data = data ?? Self.makeEmptyData(for: format, width: width, height: height)
        self.width = width
        self.height = height
        self.format = format
    }
    
    public init(width: Int, height: Int, color: Color, format: Format = .rgba8) {
        assert(width > 0, "Width must be greater than 0.")
        assert(height > 0, "Height must be greater than 0.")
        
        self.data = Self.makeEmptyData(for: format, width: width, height: height, color: color)
        self.width = width
        self.height = height
        self.format = format
    }

    public required init(assetFrom data: Data) throws {
        fatalError()
    }
    
    public func setPixel(in position: Point, color: Color) {
        let offset = Int(position.y) * self.width + Int(position.x)
        
        Self.setPixel(with: offset, color: color, in: &self.data, format: self.format)
    }
    
    public func getPixel(in position: Point) -> Color {
        let offset = Int(position.y) * self.width + Int(position.x)
        
        switch self.format {
        case .rgb8:
            let red     = Float(self.data[offset * 3 + 0]) / 255
            let green   = Float(self.data[offset * 3 + 1]) / 255
            let blue    = Float(self.data[offset * 3 + 2]) / 255
            
            return Color(red, green, blue, 1)
        case .rgba8:
            let red     = Float(self.data[offset * 4 + 0]) / 255
            let green   = Float(self.data[offset * 4 + 1]) / 255
            let blue    = Float(self.data[offset * 4 + 2]) / 255
            let alpha   = Float(self.data[offset * 4 + 3]) / 255
            
            return Color(red, green, blue, alpha)
        case .bgra8:
            let blue    = Float(self.data[offset * 4 + 0]) / 255
            let green   = Float(self.data[offset * 4 + 1]) / 255
            let red     = Float(self.data[offset * 4 + 2]) / 255
            let alpha   = Float(self.data[offset * 4 + 3]) / 255
            
            return Color(red, green, blue, alpha)
        default:
            fatalError("Not supported format to get pixel.")
        }
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
    
    convenience init(contentsOf file: URL) throws {
        guard let loader = Self.loaders.first(where: { $0.canDecodeImage(with: file.pathExtension) }) else {
            throw LoadingError.formatNotSupported(file.pathExtension)
        }
        
        let data = try Data(contentsOf: file, options: .uncached)
        let image = try loader.decodeImage(from: data)
        
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
    
    public func encodeContents() throws -> Data {
        fatalError()
    }
}

private extension Image {
    static func makeEmptyData(
        for format: Format,
        width: Int,
        height: Int,
        color: Color? = nil
    ) -> Data {
        let stride = self.getPixelSize(for: format)
        let size = width * height
        var data = Data(repeating: 0, count: size * stride)
        
        guard let color = color else {
            return data
        }
        
        var currentIndex = 0
        
        while currentIndex < size {
            Self.setPixel(with: currentIndex, color: color, in: &data, format: format)
            currentIndex += 1
        }
        
        return data
    }
    
    static func getPixelSize(for format: Format) -> Int {
        switch format {
        case .rgba8, .bgra8:
            return 4
        case .rgb8:
            return 3
        case .gray:
            return 1
        }
    }
    
    static func setPixel(with offset: Int, color: Color, in data: inout Data, format: Format) {
        switch format {
        case .rgb8:
            data[offset * 3 + 0] = UInt8(clamp(color.red * 255.0, 0, 255))
            data[offset * 3 + 1] = UInt8(clamp(color.green * 255.0, 0, 255))
            data[offset * 3 + 2] = UInt8(clamp(color.blue * 255.0, 0, 255))
        case .rgba8:
            data[offset * 4 + 0] = UInt8(clamp(color.red * 255.0, 0, 255))
            data[offset * 4 + 1] = UInt8(clamp(color.green * 255.0, 0, 255))
            data[offset * 4 + 2] = UInt8(clamp(color.blue * 255.0, 0, 255))
            data[offset * 4 + 3] = UInt8(clamp(color.alpha * 255.0, 0, 255))
        case .bgra8:
            data[offset * 4 + 0] = UInt8(clamp(color.blue * 255.0, 0, 255))
            data[offset * 4 + 1] = UInt8(clamp(color.green * 255.0, 0, 255))
            data[offset * 4 + 2] = UInt8(clamp(color.red * 255.0, 0, 255))
            data[offset * 4 + 3] = UInt8(clamp(color.alpha * 255.0, 0, 255))
        default:
            fatalError("Not supported type for set pixel")
        }
    }
}
