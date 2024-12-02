//
//  ExportCodable.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/22/23.
//

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

extension CodingName {
    nonisolated(unsafe) static var editor = CodingName(stringValue: "_editor")
    nonisolated(unsafe) static var value = CodingName(stringValue: "_value")
}
