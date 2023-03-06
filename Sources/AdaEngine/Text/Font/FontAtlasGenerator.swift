//
//  File.swift
//  
//
//  Created by v.prusakov on 3/5/23.
//

import AtlasFontGenerator

class FontHandle {
    
    let atlasTexture: Texture2D
    let fontData: UnsafePointer<ada_font.FontData>
    
    init(atlasTexture: Texture2D, fontData: UnsafePointer<ada_font.FontData>) {
        self.atlasTexture = atlasTexture
        self.fontData = fontData
    }
    
    deinit {
        fontData.deallocate()
    }
}

public struct FontDescriptor {
    public var fontSize: Float = 1.0
}

final class FontAtlasGenerator {
    
    static let shared = FontAtlasGenerator()
    
    private init() {}
    
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
        let fontData = fontGenerator.__getFontDataUnsafe()
        let bitmap = fontGenerator.__getBitmapUnsafe()
        let data = Data(bytes: bitmap.pixels, count: Int(bitmap.pixelsCount))

        let image = Image(
            width: Int(bitmap.bitmapWidth),
            height: Int(bitmap.bitmapHeight),
            data: data
        )
        
        let descriptor = TextureDescriptor(
            width: Int(bitmap.bitmapWidth),
            height: Int(bitmap.bitmapHeight),
            pixelFormat: .rgba_32f,
            textureUsage: [.read],
            textureType: .texture2D,
            mipmapLevel: 0,
            image: image
        )
        
        let texture = Texture2D(descriptor: descriptor)
        return FontHandle(atlasTexture: texture, fontData: fontData!)
    }
    
    // MARK: - Private
    
    private func getCacheDirectory() throws -> URL {
        return try FileSystem.current.url(for: .cachesDirectory).appendingPathComponent("FontGeneratedAtlases")
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
    
    private func saveAtlas(data: Data) {
        
    }
}
