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
    func initialize(from decoder: Decoder, key: CodingName) throws {
        let container = try decoder.container(keyedBy: CodingName.self)
        self.wrappedValue = try container.decode(T.self, forKey: key)
    }
    
    func encode(from encoder: Encoder, key: CodingName) throws {
        var container = encoder.container(keyedBy: CodingName.self)
        try container.encode(self.wrappedValue, forKey: key)
    }
}

/// Helper to avoid generics problems
protocol _ExportCodable {
    func initialize(from decoder: Decoder, key: CodingName) throws
    func encode(from encoder: Encoder, key: CodingName) throws
}

struct CodingName: CodingKey {
    var stringValue: String
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    var intValue: Int?
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = ""
    }
}
