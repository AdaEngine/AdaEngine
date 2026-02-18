//
//  FontAtlasGenerator.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/5/23.
//

import AdaRender
import AdaUtils
import AtlasFontGenerator
import Foundation
import Logging

/// A font descriptor.
public struct FontDescriptor {
    /// The em font scale.
    public var emFontScale: Double
}

/// Generate MTSDF atlas texture from font.
final class FontAtlasGenerator: Sendable {

    static let shared = FontAtlasGenerator()

    private let logger = Logger(label: "org.adaengine.Font")

    private init() {}
    
    /// Generate and save to the disk info about font atlas.
    ///
    /// - Parameter fontPath: The path to the font.
    /// - Parameter fontDescriptor: The font descriptor.
    /// - Returns: The font handle.
    func generateAtlas(fontPath: URL, fontDescriptor: FontDescriptor) -> FontHandle? {
        var atlasFontDescriptor = font_atlas_descriptor()
        atlasFontDescriptor.angleThreshold = 3.0
        atlasFontDescriptor.atlasPixelRange = 2.0
        atlasFontDescriptor.coloringSeed = 3
        atlasFontDescriptor.threads = 8
        atlasFontDescriptor.expensiveColoring = 1
        atlasFontDescriptor.emFontScale = fontDescriptor.emFontScale
        atlasFontDescriptor.atlasImageType = AFG_IMAGE_TYPE_MTSDF
        atlasFontDescriptor.miterLimit = 1.0
        
        let fontPathString = fontPath.path
        let fontName = fontPath.lastPathComponent
        
        let generator = unsafe fontPathString.withCString { fontPathPtr in
            unsafe fontName.withCString { fontNamePtr in
                unsafe font_atlas_generator_create(fontPathPtr, fontNamePtr, atlasFontDescriptor)!
            }
        }
        
        defer {
            unsafe font_atlas_generator_destroy(generator)
        }
        
        let fontData = unsafe font_atlas_generator_get_font_data(generator)!
        let fileName = "\(fontName)-\(atlasFontDescriptor.emFontScale.rounded()).fontbin"

        if let (atlasHeader, data) = self.getAtlas(by: fileName) {
            let texture = self.makeTextureAtlas(from: data, width: atlasHeader.width, height: atlasHeader.height)
            return unsafe FontHandle(atlasTexture: texture, fontData: fontData)
        } else {
            let bitmap = unsafe font_atlas_generator_generate_bitmap(generator)!

            defer {
                unsafe font_atlas_bitmap_destroy(bitmap)
            }
            
            let bitmapValue = unsafe bitmap.pointee
            let data = unsafe Data(bytes: bitmapValue.pixels!, count: Int(bitmapValue.pixelsCount))

            let width = unsafe Int(bitmapValue.bitmapWidth)
            let height = unsafe Int(bitmapValue.bitmapHeight)

            assert(width > 0, "Invalid width of atlas")
            assert(height > 0, "Invalid width of atlas")

            self.saveAtlas(data, width: width, height: height, fileName: fileName)

            let texture = self.makeTextureAtlas(from: data, width: width, height: height)
            return unsafe FontHandle(atlasTexture: texture, fontData: fontData)
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
            fatalError("[FontAtlasGenerator] \(error)")
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
            unsafe withUnsafeBytes(of: &header) { ptr in
                let bytes = unsafe ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                unsafe stream.write(bytes, maxLength: MemoryLayout<AtlasHeader>.stride)
            }
            
            unsafe data.withUnsafeBytes { (bufferPtr: UnsafeRawBufferPointer) in
                let bytes = unsafe bufferPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                unsafe stream.write(bytes, maxLength: data.count)
            }
            
            stream.close()
        } catch {
            logger.error("\(error)")
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
            unsafe stream.read(headerData, maxLength: MemoryLayout<AtlasHeader>.size)
            let atlasHeader = unsafe UnsafeRawPointer(headerData).load(as: AtlasHeader.self)

            let atlasData: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: atlasHeader.dataSize)
            unsafe stream.read(atlasData, maxLength: atlasHeader.dataSize)
            let data = unsafe Data(bytes: UnsafeRawPointer(atlasData), count: atlasHeader.dataSize)

            defer {
                unsafe headerData.deallocate()
                unsafe atlasData.deallocate()

                stream.close()
            }
            
            return (atlasHeader, data)
        } catch {
            logger.error("\(error)")
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
