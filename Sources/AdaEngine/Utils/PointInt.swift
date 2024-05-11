//
//  PointInt.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/5/24.
//

public struct PointInt: Codable, Equatable, Hashable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

extension PointInt: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Int...) {
        assert(elements.count == 2)
        self.x = elements[0]
        self.y = elements[1]
    }
}
