//
//  File.swift
//  
//
//  Created by v.prusakov on 6/28/22.
//

import Foundation
import Yams

public final class Texture2D: Texture {
    
    public convenience init(from image: Image) {
        let rid = RenderEngine.shared.renderBackend.makeTexture(from: image, type: .texture2D, usage: [.read, .write, .render])
        
        self.init(rid: rid, textureType: .texture2D)
    }
}

// MARK: - Resource

extension Texture2D: Resource {
    
    struct TextureRepresentation: Codable {
        let type: TextureType
        let imageData: Data
    }
    
    public static func load(from data: Data) async throws -> Texture2D {
        let decoder = YAMLDecoder()
        let representation = try decoder.decode(TextureRepresentation.self, from: data)

        let image = try await Image.load(from: representation.imageData)
        
        let rid = RenderEngine.shared.renderBackend.makeTexture(
            from: image,
            type: representation.type,
            usage: [.read, .render]
        )
        
        return Texture2D(rid: rid, textureType: representation.type)
    }
    
    public func encodeContents() async throws -> Data {
        guard let image = RenderEngine.shared.renderBackend.getImage(for: self.rid) else {
            throw ResourceError.message("Image not exists for texture.")
        }
        
        let imageData = try await image.encodeContents()
        
        let representation = TextureRepresentation(type: self.textureType, imageData: imageData)
        
        let encoder = YAMLEncoder()
        
        guard let data = try encoder.encode(representation).data(using: .utf8) else {
            throw ResourceError.message("Can't convert String to data.")
        }
        
        return data
    }
}
