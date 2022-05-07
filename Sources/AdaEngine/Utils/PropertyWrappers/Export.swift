//
//  Export.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

import Foundation

/// Fields marked as `@Export` can be serializable and deserializable.
/// - Note: You can use `private`, `fileprivate` modifiers, because `@Export` use reflection
@propertyWrapper
public class Export<T: Codable>: Codable {
    
    public var wrappedValue: T {
        didSet {
            self.hasChanges = true
        }
    }
    
    private var hasChanges: Bool = false
    private var editorInfo = EditorInfo()
    
    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
    
    public init(wrappedValue: T) where T: CaseIterable {
        self.wrappedValue = wrappedValue
        self.editorInfo.modifiers = .enum(EnumModifier(cases: T.allCases.map { String(describing: $0) }))
    }
}

extension Export: _ExportCodable {
    func decode(from container: DecodingContainer, propertyName: String, userInfo: [CodingUserInfoKey: Any]) throws {
        guard let value = try container.decodeIfPresent(T.self, forKey: CodingName(stringValue: propertyName)) else {
            return
        }
        
        self.wrappedValue = value
    }
    
    
    func encode(to container: inout KeyedEncodingContainer<CodingName>, propertyName: String, userInfo: [CodingUserInfoKey: Any]) throws {
        /// we have difference between initial value
        if self.hasChanges {
            try container.encode(self.wrappedValue, forKey: CodingName(stringValue: propertyName))
        }
    }
}

typealias _ExportCodable = _ExportDecodable & _ExportEncodable

/// Helper to avoid generics problems
protocol _ExportDecodable {
    typealias DecodingContainer = KeyedDecodingContainer<CodingName>
    func decode(from container: DecodingContainer, propertyName: String, userInfo: [CodingUserInfoKey: Any]) throws
}

protocol _ExportEncodable {
    typealias EncodingContainer = KeyedEncodingContainer<CodingName>
    func encode(to container: inout EncodingContainer, propertyName: String, userInfo: [CodingUserInfoKey: Any]) throws
}

public extension Export {
    convenience init(wrappedValue: T, range: ClosedRange<Float>? = nil, stride: Float? = nil) where T: FloatingPoint {
        self.init(wrappedValue: wrappedValue)
        self.editorInfo.modifiers = .float(FloatingPointModifier(range: range, stride: stride))
    }
}

extension Export {
    
    enum Modifiers: Codable {
        case float(FloatingPointModifier)
        case `enum`(EnumModifier)
    }
    
    struct FloatingPointModifier: Codable {
        let range: ClosedRange<Float>?
        let stride: Float?
    }
    
    struct EnumModifier: Codable {
        let cases: [String]
    }
    
    struct EditorInfo: Codable {
        var modifiers: Modifiers? = nil
    }
}

struct CodingName: CodingKey {
    var stringValue: String
    
    init(stringValue: String) {
        self.stringValue = stringValue
    }
    
    var intValue: Int?
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}

extension CodingUserInfoKey {
    static var editorIntrospection = CodingUserInfoKey(rawValue: "export.editor.introspection")
}
