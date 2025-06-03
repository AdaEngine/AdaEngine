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
    public static let defaultValue: Font = Font(fontResource: .system(emFontScale: 52), pointSize: 17)
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
    public static let defaultValue: Color = .clear
}

/// A text attribute key for kerning.
public struct KernColorTextAttribute: TextAttributeKey {
    /// The value type.
    public typealias Value = Float
    public static let defaultValue: Float = 0
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
    
    /// Set kerning for text.
    var kern: Float {
        get {
            self[KernColorTextAttribute.self] ?? KernColorTextAttribute.defaultValue
        }
        
        set {
            self[KernColorTextAttribute.self] = newValue
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
