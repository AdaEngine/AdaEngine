//
//  Font.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/4/22.
//

/// Contains font styles.
public enum FontWeight: String {
    case regular
    case bold
    case semibold
    case italic
    case light
    case heavy
}

/// An object that provides access to the font's characteristics.
public final class FontResource: Resource, Hashable {
    
    let handle: FontHandle
    
    init(handle: FontHandle) {
        self.handle = handle
    }
    
    public var resourceMetaInfo: ResourceMetaInfo?
    
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
        fatalErrorMethodNotImplemented()
    }
}

public extension FontResource {
    /// The top y-coordinate, offset from the baseline, of the font’s longest ascender.
    var ascender: Float {
        Float(self.handle.metrics.ascenderY)
    }
    
    /// The bottom y-coordinate, offset from the baseline, of the font’s longest descender.
    var descender: Float {
        Float(self.handle.metrics.descenderY)
    }
    
    /// The height, in points, of text lines.
    var lineHeight: Float {
        Float(self.handle.metrics.lineHeight)
    }
}

extension FontResource {
    public static func == (lhs: FontResource, rhs: FontResource) -> Bool {
        return lhs.handle == rhs.handle
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.handle)
    }
}

public extension FontResource {
    
    /// Create custom font from file path.
    /// - Returns: Returns font if font available or null if something went wrong.
    static func custom(fontPath: URL) -> FontResource? {
        let descriptor = FontDescriptor(fontSize: .zero)
        guard let fontHandle = FontAtlasGenerator.shared.generateAtlas(fontPath: fontPath, fontDescriptor: descriptor) else {
            return nil
        }
        return FontResource(handle: fontHandle)
    }
    
}

// TODO: Add cache

public extension FontResource {
    
    /// Returns default font from AdaEngine bundle.
    static func system(weight: FontWeight = .regular) -> FontResource {
        do {
            return try ResourceManager.loadSync("Fonts/opensans/OpenSans-\(weight.rawValue.capitalized).ttf", from: .engineBundle) as FontResource
        } catch {
            fatalError("[Font]: Something went wrong \(error.localizedDescription)")
        }
    }
}
