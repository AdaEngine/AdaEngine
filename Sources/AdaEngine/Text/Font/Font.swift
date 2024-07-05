//
//  Font.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 09.06.2024.
//

public struct Font: Hashable, Equatable {
    
    public let name: String
    public let familyFont: String
    public let pointSize: Double
    
    let fontResource: FontResource
    
    internal init(fontResource: FontResource, pointSize: Double) {
        self.pointSize = pointSize
        self.fontResource = fontResource
        self.name = fontResource.handle.fontName
        
        self.familyFont = ""
    }
}

public extension Font {
    static func system(size: Double, weight: Weight? = nil) -> Font {
        let resource = FontResource.system(weight: FontWeight.regular, emFontScale: 52)
        return Font(fontResource: resource, pointSize: size)
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
    public struct Weight: Equatable, Hashable {
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
