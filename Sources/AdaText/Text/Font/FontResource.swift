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

    private struct CacheKey: Hashable {
        let path: String
        let emFontScale: Double
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
        let resolvedScale = emFontScale ?? Constants.defaultEmFontScale
        let key = CacheKey(path: fontPath.path, emFontScale: resolvedScale)

        if let cached = cacheStore.get(key) {
            return cached
        }

        let descriptor = FontDescriptor(
            emFontScale: resolvedScale
        )
        guard let fontHandle = FontAtlasGenerator.shared.generateAtlas(fontPath: fontPath, fontDescriptor: descriptor) else {
            return nil
        }
        let resource = FontResource(handle: fontHandle)
        cacheStore.set(resource, for: key)
        return resource
    }
    
}

// TODO: Add cache

public extension FontResource {
    
    /// Returns default font from AdaEngine bundle.
    static func system(weight: FontWeight = .regular, emFontScale: Double? = nil) -> FontResource {
        do {
            let resolvedScale = emFontScale ?? Constants.defaultEmFontScale
            var path = "Assets/Fonts/opensans/OpenSans-\(weight.rawValue.capitalized).ttf"

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
