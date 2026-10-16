#if !canImport(CoreGraphics) || !canImport(ImageIO)
import AdaRender
import Foundation
import Testing

@Suite("Portable PNG encoding")
struct PortablePNGTests {
    @Test("PNG round trip preserves channels and alpha", arguments: [Image.Format.rgba8, .bgra8, .bgra8_sRGB, .rgb8, .gray])
    func roundTrip(format: Image.Format) throws {
        let bytes: [UInt8]
        switch format {
        case .rgba8: bytes = [255, 32, 64, 128, 0, 128, 255, 255]
        case .bgra8, .bgra8_sRGB: bytes = [64, 32, 255, 128, 255, 128, 0, 255]
        case .rgb8: bytes = [255, 32, 64, 0, 128, 255]
        case .gray: bytes = [32, 128]
        }
        let original = Image(width: 2, height: 1, data: Data(bytes), format: format)
        let decoded = try Image.decode(from: original.pngData())
        #expect(decoded.width == 2)
        #expect(decoded.height == 1)
        let expected: [UInt8] = format == .gray
            ? [32, 32, 32, 255, 128, 128, 128, 255]
            : [255, 32, 64, format == .rgb8 ? 255 : 128, 0, 128, 255, 255]
        #expect(decoded.data == Data(expected))
    }

    @Test("Malformed pixel buffers fail before entering libpng")
    func invalidPixels() {
        let image = Image(width: 2, height: 1, data: Data([0]), format: .rgba8)
        #expect(throws: ImagePNGEncodingError.self) { try image.pngData() }
    }
}
#endif
