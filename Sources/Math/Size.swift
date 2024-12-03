//
//  Size.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/16/22.
//

public struct Size: Equatable, Codable, Hashable, Comparable, Sendable {
    public var width: Float
    public var height: Float
    
    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }

    public static func < (lhs: Size, rhs: Size) -> Bool {
        lhs.width < rhs.width && lhs.height < rhs.height
    }
}

public extension Size {
    var asVector2: Vector2 {
        unsafeBitCast(self, to: Vector2.self)
    }
}

public extension Vector2 {
    var asSize: Size {
        unsafeBitCast(self, to: Size.self)
    }
}

public extension Size {
    @inline(__always)
    nonisolated static let zero = Size(width: 0, height: 0)

    @inline(__always)
    static let infinity = Size(width: .infinity, height: .infinity)
}

extension Size: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Float...) {
        assert(elements.count == 2, "Array must be contains only two elements.")
        
        self.init(width: elements[0], height: elements[1])
    }
}

extension Size {
    public func toSizeInt() -> SizeInt {
        .init(width: Int(self.width), height: Int(self.height))
    }
}

public extension Size {
    static func += (lhs: inout Size, rhs: Size) {
        lhs = lhs + rhs
    }

    static func + (lhs: Size, rhs: Size) -> Size {
        return Size(
            width: lhs.width + rhs.width,
            height: rhs.height + lhs.height
        )
    }
}
