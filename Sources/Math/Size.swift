//
//  Size.swift
//  
//
//  Created by v.prusakov on 5/16/22.
//

public struct Size: Equatable, Codable, Hashable {
    public var width: Float
    public var height: Float
    
    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }
}

public extension Size {
    static let zero = Size(width: 0, height: 0)
}
