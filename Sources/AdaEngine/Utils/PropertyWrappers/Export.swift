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
public class Export<T: Codable> {
    public var wrappedValue: T
    
    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}

extension Export: _ExportCodable {
    func decode(from container: DecodingContainer, propertyName: String) throws {
        self.wrappedValue = try container.decode(T.self, forKey: CodingName(stringValue: propertyName))
    }
    
    
    func encode(to container: inout KeyedEncodingContainer<CodingName>, propertyName: String) throws {
        try container.encode(self.wrappedValue, forKey: CodingName(stringValue: propertyName))
    }
    
}

typealias _ExportCodable = _ExportDecodable & _ExportEncodable

/// Helper to avoid generics problems
protocol _ExportDecodable {
    typealias DecodingContainer = KeyedDecodingContainer<CodingName>
    func decode(from container: DecodingContainer, propertyName: String) throws
}

protocol _ExportEncodable {
    typealias EncodingContainer = KeyedEncodingContainer<CodingName>
    func encode(to container: inout EncodingContainer, propertyName: String) throws
}

struct CodingName: CodingKey {
    var stringValue: String
    
    init(stringValue: String) {
        self.stringValue = stringValue
    }
    
    var intValue: Int?
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = ""
    }
}
