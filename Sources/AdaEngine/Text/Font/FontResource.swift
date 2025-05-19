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
public final class FontResource: Asset, Hashable, @unchecked Sendable {

    let handle: FontHandle
    
    init(handle: FontHandle) {
        self.handle = handle
    }
    
    public var assetMetaInfo: AssetMetaInfo?
    
    public static var assetType: AssetType {
        return .font
    }
    
    public required convenience init(asset decoder: AssetDecoder) throws {
        let emSizeStr = decoder.assetMeta.queryParams.first(where: { $0.name == "emSize" })?.value ?? ""
        let emSize = Double(emSizeStr)
        guard let handle = Self.custom(fontPath: decoder.assetMeta.filePath, emFontScale: emSize)?.handle else {
            throw AssetDecodingError.decodingProblem("Font not found at path \(decoder.assetMeta.filePath)")
        }
        self.init(handle: handle)
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalErrorMethodNotImplemented()
    }
}

public extension FontResource {

    /// Returns font scale for font size.
    func getFontScale(for size: Double) -> Double {
        return size / self.fontEmSize
    }

    /// The top y-coordinate, offset from the baseline, of the font’s longest ascender.
    var ascender: Double {
        self.handle.metrics.ascenderY
    }
    
    /// The bottom y-coordinate, offset from the baseline, of the font’s longest descender.
    var descender: Double {
        self.handle.metrics.descenderY
    }
    
    /// The height, in points, of text lines.
    var lineHeight: Double {
        self.handle.metrics.lineHeight
    }

    // The size of one EM.
    var fontEmSize: Double {
        self.handle.metrics.emSize
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

    private enum Constants {
        static let defaultEmFontScale: Double = 52
    }

    /// Create custom font from file path.
    /// - Returns: Returns font if font available or null if something went wrong.
    static func custom(fontPath: URL, emFontScale: Double? = nil) -> FontResource? {
        let descriptor = FontDescriptor(
            emFontScale: emFontScale ?? Constants.defaultEmFontScale
        )
        guard let fontHandle = FontAtlasGenerator.shared.generateAtlas(fontPath: fontPath, fontDescriptor: descriptor) else {
            return nil
        }
        return FontResource(handle: fontHandle)
    }
    
}

// TODO: Add cache

public extension FontResource {
    
    /// Returns default font from AdaEngine bundle.
    static func system(weight: FontWeight = .regular, emFontScale: Double? = nil) -> FontResource {
        do {
            var path = "Fonts/opensans/OpenSans-\(weight.rawValue.capitalized).ttf"

            if let scale = emFontScale {
                path.append("#emSize=\(scale)")
            }

            return try AssetsManager.loadSync(path, from: .engineBundle) as FontResource
        } catch {
            fatalError("[Font]: Something went wrong \(error.localizedDescription)")
        }
    }
}
