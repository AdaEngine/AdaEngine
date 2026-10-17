#if !canImport(CoreGraphics) || !canImport(ImageIO)
import Foundation
import libpng

public enum ImagePNGEncodingError: Error {
    case invalidPixels
    case encodingFailed
}

extension Image {
    /// Encodes CPU pixels with libpng on platforms without ImageIO.
    public func pngData() throws -> Data {
        guard width > 0, height > 0, width <= Int(UInt32.max), height <= Int(UInt32.max) else {
            throw ImagePNGEncodingError.invalidPixels
        }
        let channels: Int
        let pngFormat: UInt32
        switch format {
        case .rgba8: channels = 4; pngFormat = UInt32(PNG_FORMAT_FLAG_COLOR | PNG_FORMAT_FLAG_ALPHA)
        case .bgra8, .bgra8_sRGB: channels = 4; pngFormat = UInt32(PNG_FORMAT_FLAG_COLOR | PNG_FORMAT_FLAG_ALPHA | PNG_FORMAT_FLAG_BGR)
        case .rgb8: channels = 3; pngFormat = UInt32(PNG_FORMAT_FLAG_COLOR)
        case .gray: channels = 1; pngFormat = 0
        }
        let (pixels, pixelOverflow) = width.multipliedReportingOverflow(by: height)
        let (bytes, byteOverflow) = pixels.multipliedReportingOverflow(by: channels)
        guard !pixelOverflow, !byteOverflow, data.count == bytes else { throw ImagePNGEncodingError.invalidPixels }

        var image = unsafe png_image()
        unsafe image.version = UInt32(PNG_IMAGE_VERSION)
        unsafe image.width = UInt32(width)
        unsafe image.height = UInt32(height)
        unsafe image.format = pngFormat
        defer { unsafe png_image_free(&image) }
        var count: png_alloc_size_t = 0
        let measured = unsafe data.withUnsafeBytes { pixels in
            unsafe png_image_write_to_memory(&image, nil, &count, 0, pixels.baseAddress, 0, nil)
        }
        guard measured == 1, count > 0, count <= Int.max else { throw ImagePNGEncodingError.encodingFailed }
        var output = Data(count: Int(count))
        let written = unsafe output.withUnsafeMutableBytes { buffer in
            unsafe data.withUnsafeBytes { pixels in
                unsafe png_image_write_to_memory(&image, buffer.baseAddress, &count, 0, pixels.baseAddress, 0, nil)
            }
        }
        guard written == 1 else { throw ImagePNGEncodingError.encodingFailed }
        output.count = Int(count)
        return output
    }

    public func writePNG(to url: URL) throws {
        #if os(WASI)
        try pngData().write(to: url)
        #else
        try pngData().write(to: url, options: .atomic)
        #endif
    }
}
#endif
