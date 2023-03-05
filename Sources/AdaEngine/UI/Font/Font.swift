//
//  Font.swift
//  
//
//  Created by v.prusakov on 7/4/22.
//

public struct Font {
    
    let handle: FontHandle
    
    init(handle: FontHandle) {
        self.handle = handle
    }
    
    public static func custom(fontPath: URL, size: Float) -> Texture2D? {
        let descriptor = FontDescriptor(fontSize: size)
        return FontAtlasGenerator.shared.generateAtlas(fontPath: fontPath, fontDescriptor: descriptor)?.atlasTexture
    }
    
}
