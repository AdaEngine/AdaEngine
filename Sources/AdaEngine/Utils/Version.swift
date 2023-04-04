//
//  Version.swift
//  
//
//  Created by v.prusakov on 1/20/23.
//

public struct Version: Codable {
    
    public let components: [Int]
    public let string: String
    
    public init(string: String) {
        self.string = string
        self.components = string.split(separator: ".").compactMap { Int($0) }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
        self = Self.init(string: string)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.string)
    }
}

extension Version: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = Version(string: value)
    }
}

extension Version: Comparable {
    // MARK: - Comparable Helper
    public static func < (lhs: Version, rhs: Version) -> Bool {
        return self.compare(lhs: lhs, rhs: rhs, defaultIfAllEqual: false, block: <)
    }
    
    public static func == (lhs: Version, rhs: Version) -> Bool {
        return self.compare(lhs: lhs, rhs: rhs, defaultIfAllEqual: true) { (_, _) in return false }
    }
}

fileprivate extension Version {
    // MARK: - Comparable
    static func compare(lhs: Version, rhs: Version, defaultIfAllEqual default: Bool, block: @escaping ((Int, Int) -> Bool)) -> Bool {
        let compareCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<compareCount {
            let leftVersion = lhs.components.indices.contains(index) ? lhs.components[index] : 0
            let rightVersion = rhs.components.indices.contains(index) ? rhs.components[index] : 0
            
            if leftVersion != rightVersion { return block(leftVersion, rightVersion) }
        }
        return `default`
    }
}
