//
//  Texture2D.swift
//  
//
//  Created by v.prusakov on 6/28/22.
//

import Foundation
import Yams

/// The base class represented 2D texture.
/// When texture not holded by any object, than GPU resource will free immediately.
open class Texture2D: Texture {
    
    public private(set) var width: Float
    public private(set) var height: Float
    
    public init(from image: Image) {
        let rid = RenderEngine.shared.renderBackend.makeTexture(from: image, type: .texture2D, usage: [.read, .render])
        
        self.width = Float(image.width)
        self.height = Float(image.height)
        
        super.init(rid: rid, textureType: .texture2D)
    }
    
    open internal(set) var textureCoordinates: [Vector2] = [
        [0, 1], [1, 1], [1, 0], [0, 0]
    ]
    
    internal init(rid: RID, size: Size) {
        self.width = size.width
        self.height = size.height
        
        super.init(rid: rid, textureType: .texture2D)
    }
    
    // MARK: - Resource
    
    struct TextureRepresentation: Codable {
        let type: TextureType
        let imageData: Data
    }
    
    public required init(assetFrom data: Data) async throws {
        let decoder = YAMLDecoder()
        let representation = try decoder.decode(TextureRepresentation.self, from: data)

        let image = try await Image(assetFrom: representation.imageData)
        
        let rid = RenderEngine.shared.renderBackend.makeTexture(
            from: image,
            type: representation.type,
            usage: [.read, .render]
        )
        
        self.width = Float(image.width)
        self.height = Float(image.height)
        
        super.init(rid: rid, textureType: representation.type)
    }

    public override func encodeContents() async throws -> Data {
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
