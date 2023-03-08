//
//  File.swift
//  
//
//  Created by v.prusakov on 3/5/23.
//

import AtlasFontGenerator
import Foundation

/// Hold information about font data and atlas
final class FontHandle: Hashable {
    
    let atlasTexture: Texture2D
    let fontData: UnsafePointer<ada_font.FontData>
    
    init(
        atlasTexture: Texture2D,
        fontData: UnsafePointer<ada_font.FontData>) {
        self.atlasTexture = atlasTexture
        self.fontData = fontData
    }
    
    deinit {
        fontData.deallocate()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(fontData.pointee.fontGeometry.__getNameUnsafe())
        hasher.combine(fontData.pointee.fontGeometry.getGeometryScale())
        hasher.combine(fontData.pointee.fontGeometry.__getMetricsUnsafe().pointee.emSize)
        hasher.combine(fontData.pointee.fontGeometry.__getMetricsUnsafe().pointee.lineHeight)
    }
    
    static func == (lhs: FontHandle, rhs: FontHandle) -> Bool {
        let lhsFontGeometry = lhs.fontData.pointee.fontGeometry
        let rhsFontGeometry = rhs.fontData.pointee.fontGeometry
        
        return lhsFontGeometry.__getNameUnsafe() == rhsFontGeometry.__getNameUnsafe()
        && lhsFontGeometry.getGeometryScale() == rhsFontGeometry.getGeometryScale()
        && lhsFontGeometry.__getMetricsUnsafe().pointee.emSize == rhsFontGeometry.__getMetricsUnsafe().pointee.emSize
        && lhsFontGeometry.__getMetricsUnsafe().pointee.lineHeight == rhsFontGeometry.__getMetricsUnsafe().pointee.lineHeight
        && lhs.fontData.pointee.glyphs.size() == rhs.fontData.pointee.glyphs.size()
    }
    
}

public struct FontDescriptor {
    public var fontSize: Float = 1.0
}

final class FontAtlasGenerator {
    
    static let shared = FontAtlasGenerator()
    
    private init() {}
    
    /// Generate and save to the disk info about font atlas.
    func generateAtlas(fontPath: URL, fontDescriptor: FontDescriptor) -> FontHandle? {
        var atlasFontDescriptor = ada_font.AtlasFontDescriptor()
        atlasFontDescriptor.angleThreshold = 3.0
        atlasFontDescriptor.atlasPixelRange = 2.0
        atlasFontDescriptor.coloringSeed = 3
        atlasFontDescriptor.threads = 8
        atlasFontDescriptor.expensiveColoring = true
        atlasFontDescriptor.fontScale = 52
        atlasFontDescriptor.atlasImageType = msdf_atlas.ImageType.MTSDF
        atlasFontDescriptor.miterLimit = 1.0
        
        let fontPathString = fontPath.path
        let fontName = fontPath.lastPathComponent
        
        var fontGenerator = ada_font.FontAtlasGenerator(fontPathString, fontName, atlasFontDescriptor)
        let fontData = fontGenerator.__getFontDataUnsafe()!
        
        let fileName = "\(fontName)-\(atlasFontDescriptor.fontScale.rounded()).fontbin"
        
        if let (atlasHeader, data) = self.getAtlas(by: fileName) {
            let texture = makeTextureAtlas(from: data, width: atlasHeader.width, height: atlasHeader.height)
            return FontHandle(atlasTexture: texture, fontData: fontData)
        } else {
            let bitmap = fontGenerator.__generateAtlasBitmapUnsafe()
            let data = Data(bytes: bitmap.pixels, count: Int(bitmap.pixelsCount))
            
            let width = Int(bitmap.bitmapWidth)
            let height = Int(bitmap.bitmapHeight)
            
            self.saveAtlas(data, width: width, height: height, fileName: fileName)
            
            let texture = makeTextureAtlas(from: data, width: width, height: height)
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
        
        let descriptor = TextureDescriptor(
            width: width,
            height: height,
            pixelFormat: .rgba_32f,
            textureUsage: [.read],
            textureType: .texture2D,
            mipmapLevel: 0,
            image: image
        )
        
        return Texture2D(descriptor: descriptor)
    }
    
    private func getCacheDirectory() throws -> URL {
        return try FileSystem.current.url(for: .cachesDirectory).appendingPathComponent("AdaEngine").appendingPathComponent("FontGeneratedAtlases")
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
