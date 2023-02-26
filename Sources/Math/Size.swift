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
    var asVector2: Vector2 {
        unsafeBitCast(self, to: Vector2.self)
    }
}

public extension Size {
    @inline(__always)
    static let zero = Size(width: 0, height: 0)
}

extension Size: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Float...) {
        assert(elements.count == 2, "Array must be contains only two elements.")
        
        self.init(width: elements[0], height: elements[1])
    }
}
