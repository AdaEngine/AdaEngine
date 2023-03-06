//
//  AttributedText.swift
//  
//
//  Created by v.prusakov on 3/5/23.
//

public protocol TextAttribute {
    associatedtype Value
    
    static var defaultValue: Value { get }
}

public struct FontTextAttribute: TextAttribute {
    public typealias Value = Font
    public static var defaultValue: Font = Font.system(weight: .regular)
}

public struct ForegroundColorTextAttribute: TextAttribute {
    public typealias Value = Color
    public static var defaultValue: Color = .black
}

public extension TextAttributeValues {
    var foregroundColor: Color {
        get {
            self[ForegroundColorTextAttribute.self]
        }
        
        set {
            self[ForegroundColorTextAttribute.self] = newValue
        }
    }
    
    var font: Font {
        get {
            self[FontTextAttribute.self]
        }
        
        set {
            self[FontTextAttribute.self] = newValue
        }
    }
}

public struct TextAttributes {
    
    public var values: TextAttributeValues
    
    public init() {
        values = TextAttributeValues()
        values.font = FontTextAttribute.defaultValue
        values.foregroundColor = ForegroundColorTextAttribute.defaultValue
    }
    
    init(values: TextAttributeValues) {
        self.values = values
    }
    
    public mutating func merge(_ attributes: TextAttributes, uniquingKeysWith: (Any, Any) -> Any) {
        self.values.container.merge(attributes.values.container, uniquingKeysWith: uniquingKeysWith)
    }
    
    public mutating func merging(_ attributes: TextAttributes, uniquingKeysWith: (Any, Any) -> Any) -> TextAttributes {
        let newContainer = self.values.container.merging(attributes.values.container, uniquingKeysWith: uniquingKeysWith)
        return TextAttributes(values: TextAttributeValues(container: newContainer))
    }
    
}

public struct TextAttributeValues {
    var container: [ObjectIdentifier : Any] = [:]
    
    subscript <T: TextAttribute>(_ type: T.Type) -> T.Value {
        get {
            return (self.container[ObjectIdentifier(type)] as? T.Value) ?? T.defaultValue
        }
        
        set {
            self.container[ObjectIdentifier(type), default: T.defaultValue] = newValue
        }
    }
}

public enum TextAlignment {
    case center
    case trailing
    case leading
}

public struct AttributedText {
    let text: String
    
    var attributes: [Range<String.Index> : TextAttributes] = [:]
    
    public init(_ text: String, attributes: TextAttributes) {
        self.text = text
        self.attributes = [self.text.startIndex..<self.text.endIndex : attributes]
    }
    
    init(_ text: String, attributesWithRange: [Range<String.Index> : TextAttributes]) {
        self.text = text
        self.attributes = attributesWithRange
    }
    
    public func attributes(at index: String.Index) -> TextAttributes {
        if index > self.text.endIndex || index < self.text.startIndex {
            fatalError("Index bound of range")
        }
        
        return self.attributes.first { value in
            value.key.contains(index)
        }!.value
    }
}

extension AttributedText: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value, attributes: TextAttributes())
    }
}

public extension AttributedText {
    static func + (lhs: AttributedText, rhs: AttributedText) -> AttributedText {
        let text = lhs.text + rhs.text
        
        // FIXME: Should shift ranges for new text!
        let attributes = lhs.attributes.merging(rhs.attributes) {
            return $1
        }
        
        return AttributedText(text, attributesWithRange: attributes)
    }
}

struct Glyph {
    let texture: Texture2D
    let bounds: Rect
}

enum LineBreakMode {
    case byCharWrapping
    case byWordWrapping
}
