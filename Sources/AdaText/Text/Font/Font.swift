//
//  Font.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 09.06.2024.
//

/// A font asset.
public struct Font: Hashable, Equatable, Sendable {
    /// The name of the font.
    public let name: String
    /// The family of the font.
    public let familyFont: String
    /// The point size of the font.
    public var pointSize: Double
    /// The font resource.
    let fontResource: FontResource
    
    public init(fontResource: FontResource, pointSize: Double) {
        self.pointSize = pointSize
        self.fontResource = fontResource
        self.name = fontResource.handle.fontName
        
        self.familyFont = ""
    }
}

public extension Font {
    /// Create a font from the system resources.
    ///
    /// - Parameter size: The size of the font.
    /// - Returns: The system font.
    static func system(size: Double) -> Font {
        system(size: size, weight: .regular)
    }

    /// Create a font from the system resources.
    ///
    /// - Parameters:
    ///   - size: The size of the font.
    ///   - weight: The weight of the font.
    /// - Returns: The system font.
    static func system(size: Double, weight: FontWeight) -> Font {
        let resource = FontResource.system(weight: weight, emFontScale: 74)
        return Font(fontResource: resource, pointSize: size)
    }

    /// Returns a copy of this font with semantic text traits applied.
    func applyingTraits(_ traits: TextFontTraits, scale: Double = 1) -> Font {
        guard !traits.isEmpty else {
            var font = self
            font.pointSize *= scale
            return font
        }

        let weight: FontWeight
        if traits.contains(.strong) && traits.contains(.emphasis) {
            weight = .boldItalic
        } else if traits.contains(.strong) {
            weight = .bold
        } else if traits.contains(.emphasis) {
            weight = .italic
        } else if traits.contains(.code) {
            weight = .semibold
        } else {
            weight = .regular
        }

        return Font.system(size: self.pointSize * scale, weight: weight)
    }
}

public extension Font {
    /// The top y-coordinate, offset from the baseline, of the font’s longest ascender.
    var ascender: Double {
        return self.fontResource.ascender * pointSize / self.fontResource.fontEmSize
    }
    
    /// The bottom y-coordinate, offset from the baseline, of the font’s longest descender.
    var descender: Double {
        return self.fontResource.descender * pointSize / self.fontResource.fontEmSize
    }
    
    /// The height, in points, of text lines.
    var lineHeight: Double {
        return self.fontResource.lineHeight * pointSize / self.fontResource.fontEmSize
    }
}

extension Font {
    public struct Weight: Equatable, Hashable, Sendable {
        internal let wightValue: Float
        
        public static let black: Weight = Weight(wightValue: 900)
        public static let bold: Weight = Weight(wightValue: 300)
        public static let heavy: Weight = Weight(wightValue: 300)
        public static let light: Weight = Weight(wightValue: 300)
        public static let medium: Weight = Weight(wightValue: 300)
        public static let regular: Weight = Weight(wightValue: 500)
        public static let semibold: Weight = Weight(wightValue: 300)
        public static let thin: Weight = Weight(wightValue: 300)
        public static let ultraLight: Weight = Weight(wightValue: 300)
    }
}
