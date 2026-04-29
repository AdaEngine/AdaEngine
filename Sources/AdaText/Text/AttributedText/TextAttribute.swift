//
//  TextAttribute.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/6/23.
//

import AdaUtils

/// A type that defines an attribute’s name and type.
public protocol TextAttributeKey {
    associatedtype Value: Hashable
    
    static var defaultValue: Value { get }
}

/// A text attribute key for font.
public struct FontTextAttribute: TextAttributeKey {
    /// The value type.
    public typealias Value = Font
    public static let defaultValue: Font = .system(size: 17)
}

/// A text attribute key for foreground color.
public struct ForegroundColorTextAttribute: TextAttributeKey {
    /// The value type.
    public typealias Value = Color
    public static let defaultValue: Color = .black
}

/// A text attribute key for outline color.
public struct OutlineColorTextAttribute: TextAttributeKey {
    /// The value type.
    public typealias Value = Color
    /// Not ``Color/clear`` (white RGB, zero alpha): the text fragment shader mixes
    /// `outline.rgb` with the fill at MSDF edges; that would add a light halo on dark text.
    public static let defaultValue: Color = Color(red: 0, green: 0, blue: 0, alpha: 0)
}

/// A text attribute key for background color.
public struct BackgroundColorTextAttribute: TextAttributeKey {
    /// The value type.
    public typealias Value = Color
    public static let defaultValue: Color = .clear
}

/// A text attribute key for kerning.
public struct KernColorTextAttribute: TextAttributeKey {
    /// The value type.
    public typealias Value = Float
    public static let defaultValue: Float = 0
}

/// Semantic font traits produced by text parsers.
public struct TextFontTraits: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let strong = TextFontTraits(rawValue: 1 << 0)
    public static let emphasis = TextFontTraits(rawValue: 1 << 1)
    public static let code = TextFontTraits(rawValue: 1 << 2)
}

/// A text attribute key for semantic font traits.
public struct FontTraitsTextAttribute: TextAttributeKey {
    /// The value type.
    public typealias Value = TextFontTraits
    public static let defaultValue: TextFontTraits = []
}

/// A text attribute key for relative font scaling.
public struct FontScaleTextAttribute: TextAttributeKey {
    /// The value type.
    public typealias Value = Double
    public static let defaultValue: Double = 1
}

public extension TextAttributeContainer {
    
    /// Set foreground color for text.
    var foregroundColor: Color {
        get {
            self[ForegroundColorTextAttribute.self] ?? ForegroundColorTextAttribute.defaultValue
        }
        
        set {
            self[ForegroundColorTextAttribute.self] = newValue
        }
    }
    
    /// Set font for text.
    var font: Font {
        get {
            self[FontTextAttribute.self] ?? FontTextAttribute.defaultValue
        }
        
        set {
            self[FontTextAttribute.self] = newValue
        }
    }
    
    /// Set outline color for text.
    var outlineColor: Color {
        get {
            self[OutlineColorTextAttribute.self] ?? OutlineColorTextAttribute.defaultValue
        }
        
        set {
            self[OutlineColorTextAttribute.self] = newValue
        }
    }
    
    /// Set background color for text.
    var backgroundColor: Color {
        get {
            self[BackgroundColorTextAttribute.self] ?? BackgroundColorTextAttribute.defaultValue
        }
        
        set {
            self[BackgroundColorTextAttribute.self] = newValue
        }
    }
    
    /// Set kerning for text.
    var kern: Float {
        get {
            self[KernColorTextAttribute.self] ?? KernColorTextAttribute.defaultValue
        }
        
        set {
            self[KernColorTextAttribute.self] = newValue
        }
    }

    /// Set semantic font traits for text.
    var fontTraits: TextFontTraits {
        get {
            self[FontTraitsTextAttribute.self] ?? FontTraitsTextAttribute.defaultValue
        }

        set {
            self[FontTraitsTextAttribute.self] = newValue
        }
    }

    /// Set relative font scale for text.
    var fontScale: Double {
        get {
            self[FontScaleTextAttribute.self] ?? FontScaleTextAttribute.defaultValue
        }

        set {
            self[FontScaleTextAttribute.self] = newValue
        }
    }
    
}

/// A line break mode.
public enum LineBreakMode: Sendable {
    /// Break at character boundaries.
    case byCharWrapping
    /// Break at word boundaries.
    case byWordWrapping
}

/// A text alignment.
public enum TextAlignment: Sendable {
    /// Center align the text.
    case center
    /// Trailing align the text.
    case trailing
    /// Leading align the text.
    case leading
}
