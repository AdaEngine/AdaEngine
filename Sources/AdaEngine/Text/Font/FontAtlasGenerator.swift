//
//  FontAtlasGenerator.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/5/23.
//

@_implementationOnly import AtlasFontGenerator
import Foundation

public struct FontDescriptor {
    public var emFontScale: Double
}

/// Generate MTSDF atlas texture from font.
final class FontAtlasGenerator {
    
    static let shared = FontAtlasGenerator()
    
    private init() {}
    
    /// Generate and save to the disk info about font atlas.
    func generateAtlas(fontPath: URL, fontDescriptor: FontDescriptor) -> FontHandle? {
        var atlasFontDescriptor = font_atlas_descriptor()
        atlasFontDescriptor.angleThreshold = 3.0
        atlasFontDescriptor.atlasPixelRange = 2.0
        atlasFontDescriptor.coloringSeed = 3
        atlasFontDescriptor.threads = 8
        atlasFontDescriptor.expensiveColoring = true
        atlasFontDescriptor.emFontScale = fontDescriptor.emFontScale
        atlasFontDescriptor.atlasImageType = AFG_IMAGE_TYPE_MTSDF
        atlasFontDescriptor.miterLimit = 1.0
        
        let fontPathString = fontPath.path
        let fontName = fontPath.lastPathComponent
        
        let generator = fontPathString.withCString { fontPathPtr in
            fontName.withCString { fontNamePtr in
                font_atlas_generator_create(fontPathPtr, fontNamePtr, atlasFontDescriptor)!
            }
        }
        
        defer {
            generator.deallocate()
        }
        
        let fontData = font_atlas_generator_get_font_data(generator)!
        let fileName = "\(fontName)-\(atlasFontDescriptor.emFontScale.rounded()).fontbin"

        if let (atlasHeader, data) = self.getAtlas(by: fileName) {
            let texture = self.makeTextureAtlas(from: data, width: atlasHeader.width, height: atlasHeader.height)
            return FontHandle(atlasTexture: texture, fontData: fontData)
        } else {
            let bitmap = font_atlas_generator_generate_bitmap(generator)!
            
            defer {
                bitmap.deallocate()
            }
            
            let bitmapValue = bitmap.pointee
            let data = Data(bytesNoCopy: bitmapValue.pixels, count: Int(bitmapValue.pixelsCount), deallocator: .free)

            let width = Int(bitmapValue.bitmapWidth)
            let height = Int(bitmapValue.bitmapHeight)
            
            assert(width > 0, "Invalid width of atlas")
            assert(height > 0, "Invalid width of atlas")

            self.saveAtlas(data, width: width, height: height, fileName: fileName)

            let texture = self.makeTextureAtlas(from: data, width: width, height: height)
            return FontHandle(atlasTexture: texture, fontData: fontData)
        }
    }
    
    // MARK: - Private
    
    private func makeTextureAtlas(from data: Data, width: Int, height: Int) -> Texture2D {
        let image = Image(
            width: width,
            height: height,
            data: data
        )
        
        var textSamplerDesc = SamplerDescriptor()
        textSamplerDesc.magFilter = .linear
        textSamplerDesc.mipFilter = .linear
        textSamplerDesc.minFilter = .linear
        
        let descriptor = TextureDescriptor(
            width: width,
            height: height,
            pixelFormat: .rgba_32f,
            textureUsage: [.read],
            textureType: .texture2D,
            mipmapLevel: 0,
            image: image,
            samplerDescription: textSamplerDesc
        )
        
        return Texture2D(descriptor: descriptor)
    }
    
    private func getCacheDirectory() throws -> URL {
        return try FileSystem.current.url(for: .cachesDirectory)
            .appendingPathComponent("AdaEngine")
            .appendingPathComponent("FontGeneratedAtlases")
    }
    
    private func createCacheDirectoryIfNeeded() {
        do {
            let cacheDir = try getCacheDirectory()
            
            if FileSystem.current.itemExists(at: cacheDir) {
                return
            }
            
            return try FileSystem.current.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        } catch {
            fatalError("[FontAtlasGenerator] \(error.localizedDescription)")
        }
    }
    
    private func saveAtlas(_ data: Data, width: Int, height: Int, fileName: String) {
        self.createCacheDirectoryIfNeeded()
        
        do {
            let file = try self.getCacheDirectory().appendingPathComponent(fileName)
            
            guard !FileSystem.current.itemExists(at: file) else {
                return
            }
            
            guard let stream = OutputStream(url: file, append: false) else {
                return
            }
            
            stream.open()
            
            var header = AtlasHeader(width: width, height: height, dataSize: data.count)
            withUnsafeBytes(of: &header) { ptr in
                let bytes = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                stream.write(bytes, maxLength: MemoryLayout<AtlasHeader>.stride)
            }
            
            data.withUnsafeBytes { (bufferPtr: UnsafeRawBufferPointer) in
                let bytes = bufferPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                stream.write(bytes, maxLength: data.count)
            }
            
            stream.close()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func getAtlas(by fileName: String) -> (AtlasHeader, Data)? {
        self.createCacheDirectoryIfNeeded()
        
        do {
            let file = try self.getCacheDirectory().appendingPathComponent(fileName)
            
            guard FileSystem.current.itemExists(at: file) else {
                return nil
            }
            
            guard let stream = InputStream(url: file) else {
                return nil
            }
            
            stream.open()
            
            let headerData: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: MemoryLayout<AtlasHeader>.stride)
            stream.read(headerData, maxLength: MemoryLayout<AtlasHeader>.size)
            let atlasHeader = UnsafeRawPointer(headerData).load(as: AtlasHeader.self)
            
            let atlasData: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: atlasHeader.dataSize)
            stream.read(atlasData, maxLength: atlasHeader.dataSize)
            let data = Data(bytes: UnsafeRawPointer(atlasData), count: atlasHeader.dataSize)
            
            defer {
                headerData.deallocate()
                atlasData.deallocate()
                
                stream.close()
            }
            
            return (atlasHeader, data)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    /// Contains info for binary format
    struct AtlasHeader {
        let width: Int
        let height: Int
        let dataSize: Int
    }
}
