//
//  Font.swift
//  
//
//  Created by v.prusakov on 7/4/22.
//

public enum FontWeight: String {
    case regular
    case bold
    case semibold
    case italic
    case light
    case heavy
}

public class Font: Resource {
    
    let handle: FontHandle
    
    init(handle: FontHandle) {
        self.handle = handle
    }
    
    public var resourcePath: String = ""
    public var resourceName: String = ""
    
    public static var resourceType: ResourceType {
        return .font
    }
    
    public required convenience init(asset decoder: AssetDecoder) throws {
        guard let handle = Self.custom(fontPath: decoder.assetMeta.filePath)?.handle else {
            throw AssetDecodingError.decodingProblem("Font not found at path \(decoder.assetMeta.filePath)")
        }
        self.init(handle: handle)
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalError()
    }
    
}

public extension Font {

    static func custom(fontPath: URL, size: Float = 0) -> Texture2D? {
        let descriptor = FontDescriptor(fontSize: size)
        return FontAtlasGenerator.shared.generateAtlas(fontPath: fontPath, fontDescriptor: descriptor)?.atlasTexture
    }
    
    static func custom(fontPath: URL) -> Font? {
        let descriptor = FontDescriptor(fontSize: .zero)
        guard let fontHandle = FontAtlasGenerator.shared.generateAtlas(fontPath: fontPath, fontDescriptor: descriptor) else {
            return nil
        }
        return Font(handle: fontHandle)
    }
    
}

public extension Font {
    static func system(weight: FontWeight = .regular) -> Font {
        do {
            return try ResourceManager.load("Fonts/opensans/OpenSans-\(weight.rawValue.capitalized).ttf", from: .current) as Font
        } catch {
            fatalError("[Font]: Something went wrong \(error.localizedDescription)")
        }
    }
}
