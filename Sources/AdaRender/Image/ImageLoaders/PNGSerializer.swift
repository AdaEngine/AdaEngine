//
//  PNGSerializer.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/29/22.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import libpng

/// An object that serialize png raw data to an ``Image``
struct PNGImageSerializer: ImageLoaderStrategy {
    
    enum DecodingError: String, Error {
        case cannotReadFromMemmory
        case cannotFinishReading
        case notSupportedImageFormat = "Unsupported png format"
    }
    
    // MARK: - ImageLoaderStrategy
    
    func canDecodeImage(with fileExtensions: String) -> Bool {
        return fileExtensions == "png"
    }
    
    func decodeImage(from data: Data) throws -> Image {
        var pngImage = png_image()
        pngImage.version = png_uint_32(PNG_IMAGE_VERSION)
        
        var isSuccess = data.withUnsafeBytes { bufferPtr in
            return png_image_begin_read_from_memory(&pngImage, bufferPtr.baseAddress, data.count) == 1
        }
        
        let maskFormat: UInt32 = ~(
            PNG_FORMAT_FLAG_BGR | PNG_FORMAT_FLAG_AFIRST |
            PNG_FORMAT_FLAG_LINEAR | PNG_FORMAT_FLAG_COLORMAP
        )
        
        pngImage.format &= maskFormat
        pngImage.flags |= UInt32(PNG_IMAGE_FLAG_16BIT_sRGB)
        
        let format: Image.Format
        
        switch pngImage.format {
        case PNG_FORMAT_FLAG_COLOR:
            format = .rgb8
        case (PNG_FORMAT_FLAG_COLOR | PNG_FORMAT_FLAG_ALPHA): // rgba
            format = .rgba8
        case PNG_FORMAT_FLAG_BGR:
            format = .bgra8
        case UInt32(PNG_FORMAT_GRAY):
            format = .gray
        default:
            png_image_free(&pngImage)
            throw DecodingError.notSupportedImageFormat
        }
        
        if !isSuccess {
            png_image_free(&pngImage)
            throw DecodingError.cannotReadFromMemmory
        }
        
        let stride = swift_png_image_row_stride(pngImage)
        var imageBuffer = Data(count: Int(swift_png_image_buffer_size(pngImage, stride)))
        
        isSuccess = imageBuffer.withUnsafeMutableBytes {
            png_image_finish_read(&pngImage, nil, $0.baseAddress, png_int_32(stride), nil) == 1
        }
        
        if !isSuccess {
            throw DecodingError.cannotFinishReading
        }
        
        return Image(
            width: Int(pngImage.width),
            height: Int(pngImage.height),
            data: imageBuffer,
            format: format
        )
    }
}
