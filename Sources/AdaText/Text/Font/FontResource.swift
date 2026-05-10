//
//  Font.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/4/22.
//

import AdaAssets
import AdaUtils
import Foundation
import AtlasFontGenerator
#if canImport(CoreText)
import CoreText
#endif

/// Contains font styles.
public enum FontWeight: String {
    case regular
    case bold
    case boldItalic
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

    public static func extensions() -> [String] {
        return ["ttf", "otf"]
    }
    
    public required convenience init(from decoder: AssetDecoder) throws {
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

    static func registerPrebuiltAtlasBundle(_ bundle: Bundle, subdirectory: String) {
        FontAtlasGenerator.shared.registerPrebuiltAtlasBundle(bundle, subdirectory: subdirectory)
    }

    static func prebuiltAtlasFileName(
        fontFileName: String,
        emFontScale: Double,
        includeDefaultCharset: Bool = true,
        additionalCodepoints: [UInt32] = []
    ) -> String {
        let descriptor = FontDescriptor(
            emFontScale: emFontScale,
            includeDefaultCharset: includeDefaultCharset,
            additionalCodepoints: Array(Set(additionalCodepoints)).sorted()
        )
        return FontAtlasGenerator.cacheFileName(fontName: fontFileName, fontDescriptor: descriptor)
    }

    static func prebuildCustomAtlas(
        fontPath: URL,
        emFontScale: Double? = nil,
        includeDefaultCharset: Bool = true,
        additionalCodepoints: [UInt32] = []
    ) -> Bool {
        let descriptor = FontDescriptor(
            emFontScale: emFontScale ?? Constants.defaultEmFontScale,
            includeDefaultCharset: includeDefaultCharset,
            additionalCodepoints: Array(Set(additionalCodepoints)).sorted()
        )
        return FontAtlasGenerator.shared.ensureCachedAtlas(fontPath: fontPath, fontDescriptor: descriptor)
    }

    static func hasPrebuiltAtlas(
        fontPath: URL,
        emFontScale: Double? = nil,
        includeDefaultCharset: Bool = true,
        additionalCodepoints: [UInt32] = []
    ) -> Bool {
        let descriptor = FontDescriptor(
            emFontScale: emFontScale ?? Constants.defaultEmFontScale,
            includeDefaultCharset: includeDefaultCharset,
            additionalCodepoints: Array(Set(additionalCodepoints)).sorted()
        )
        return FontAtlasGenerator.shared.hasPrebuiltCachedAtlas(fontPath: fontPath, fontDescriptor: descriptor)
    }

    static func prebuildSystemAtlas(weight: FontWeight = .regular, emFontScale: Double? = nil) -> Bool {
        let resolvedScale = emFontScale ?? Constants.defaultEmFontScale
        let fontName = "OpenSans-\(weight.fileNameComponent)"
        guard let fontPath = Bundle.module.url(
            forResource: fontName,
            withExtension: "ttf",
            subdirectory: "Assets/Fonts/opensans"
        ) else {
            return false
        }

        return prebuildCustomAtlas(fontPath: fontPath, emFontScale: resolvedScale)
    }

    private struct CacheKey: Hashable {
        let path: String
        let emFontScale: Double
        var includeDefaultCharset: Bool = true
        var additionalCodepoints: [UInt32] = []

        func covers(_ key: Self) -> Bool {
            guard path == key.path && emFontScale == key.emFontScale else {
                return false
            }

            guard includeDefaultCharset || !key.includeDefaultCharset else {
                return false
            }

            return Set(additionalCodepoints).isSuperset(of: key.additionalCodepoints)
        }
    }

    private final class CacheStore: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [CacheKey: FontResource] = [:]

        func get(_ key: CacheKey) -> FontResource? {
            lock.lock()
            defer {
                lock.unlock()
            }
            return values[key]
        }

        func getResourceCovering(_ key: CacheKey) -> FontResource? {
            lock.lock()
            defer {
                lock.unlock()
            }

            return values.first { cachedKey, _ in
                cachedKey.covers(key)
            }?.value
        }

        func set(_ value: FontResource, for key: CacheKey) {
            lock.lock()
            defer {
                lock.unlock()
            }
            values[key] = value
        }
    }

    private static let cacheStore = CacheStore()

    /// Create custom font from file path.
    /// - Returns: Returns font if font available or null if something went wrong.
    static func custom(fontPath: URL, emFontScale: Double? = nil) -> FontResource? {
        custom(
            fontPath: fontPath,
            emFontScale: emFontScale,
            includeDefaultCharset: true,
            additionalCodepoints: []
        )
    }

    static func custom(
        fontPath: URL,
        emFontScale: Double? = nil,
        includeDefaultCharset: Bool,
        additionalCodepoints: [UInt32]
    ) -> FontResource? {
        let resolvedScale = emFontScale ?? Constants.defaultEmFontScale
        let normalizedCodepoints = Array(Set(additionalCodepoints)).sorted()
        let key = CacheKey(
            path: fontPath.path,
            emFontScale: resolvedScale,
            includeDefaultCharset: includeDefaultCharset,
            additionalCodepoints: normalizedCodepoints
        )

        if let cached = cacheStore.getResourceCovering(key) {
            return cached
        }

        let descriptor = FontDescriptor(
            emFontScale: resolvedScale,
            includeDefaultCharset: includeDefaultCharset,
            additionalCodepoints: normalizedCodepoints
        )
        guard let fontHandle = FontAtlasGenerator.shared.generateAtlas(fontPath: fontPath, fontDescriptor: descriptor) else {
            return nil
        }
        let resource = FontResource(handle: fontHandle)
        cacheStore.set(resource, for: key)
        return resource
    }

    static func fallback(for scalar: UnicodeScalar, baseFont: FontResource) -> FontResource? {
        #if canImport(CoreText)
        guard let fontURL = fallbackFontURL(for: scalar, baseFontName: baseFont.handle.fontName) else {
            return nil
        }

        return custom(
            fontPath: fontURL,
            emFontScale: baseFont.fontEmSize,
            includeDefaultCharset: false,
            additionalCodepoints: [scalar.value]
        )
        #else
        return nil
        #endif
    }

    #if canImport(CoreText)
    private static func fallbackFontURL(for scalar: UnicodeScalar, baseFontName: String) -> URL? {
        let character = String(scalar)
        let baseFont = CTFontCreateWithName(baseFontName as CFString, 12, nil)
        let fallbackFont = CTFontCreateForString(
            baseFont,
            character as CFString,
            CFRange(location: 0, length: (character as NSString).length)
        )

        guard font(fallbackFont, contains: scalar) else {
            return nil
        }

        return CTFontCopyAttribute(fallbackFont, kCTFontURLAttribute) as? URL
    }

    private static func font(_ font: CTFont, contains scalar: UnicodeScalar) -> Bool {
        let characters = String(scalar).utf16.map { UniChar($0) }
        guard !characters.isEmpty else {
            return false
        }

        var glyphs = Array(repeating: CGGlyph(), count: characters.count)
        let foundGlyphs = characters.withUnsafeBufferPointer { charactersBuffer in
            glyphs.withUnsafeMutableBufferPointer { glyphsBuffer in
                CTFontGetGlyphsForCharacters(
                    font,
                    charactersBuffer.baseAddress!,
                    glyphsBuffer.baseAddress!,
                    characters.count
                )
            }
        }

        return foundGlyphs && glyphs.allSatisfy { $0 != 0 }
    }
    #endif
    
}

// TODO: Add cache

public extension FontResource {
    
    /// Returns default font from AdaEngine bundle.
    static func system(weight: FontWeight = .regular, emFontScale: Double? = nil) -> FontResource {
        do {
            let resolvedScale = emFontScale ?? Constants.defaultEmFontScale
            var path = "Assets/Fonts/opensans/OpenSans-\(weight.fileNameComponent).ttf"

            path.append("#emSize=\(resolvedScale)")

            let key = CacheKey(path: path, emFontScale: resolvedScale)
            if let cached = cacheStore.get(key) {
                return cached
            }

            guard let resource = try AssetsManager.loadSync(
                FontResource.self, 
                at: path, 
                from: .module
            ).asset else {
                fatalError("[Font]: Failed to load system font resource at path \(path)")
            }

            cacheStore.set(resource, for: key)
            return resource
        } catch {
            fatalError("[Font]: Something went wrong \(error)")
        }
    }
}

private extension FontWeight {
    var fileNameComponent: String {
        switch self {
        case .boldItalic:
            return "BoldItalic"
        default:
            return self.rawValue.capitalized
        }
    }
}
