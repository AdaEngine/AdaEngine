//
//  Rect.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/16/22.
//

public struct Rect: Equatable, Codable, Hashable {
    public var origin: Point
    public var size: Size
    
    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }
}

public extension Rect {
    @inline(__always)
    static let zero = Rect(origin: .zero, size: .zero)
    
    init(x: Float, y: Float, width: Float, height: Float) {
        self.origin = [x, y]
        self.size = Size(width: width, height: height)
    }
}

public extension Rect {
    
    @inline(__always)
    var minX: Float {
        return self.origin.x
    }
    
    @inline(__always)
    var midX: Float {
        return self.minX + self.width / 2
    }
    
    @inline(__always)
    var maxX: Float {
        return self.minX + self.width
    }
    
    @inline(__always)
    var minY: Float {
        return self.origin.y
    }
    
    @inline(__always)
    var midY: Float {
        return self.minY + self.height / 2
    }
    
    @inline(__always)
    var maxY: Float {
        return self.minY + self.height
    }
    
    @inline(__always)
    var width: Float {
        return self.size.width
    }
    
    @inline(__always)
    var height: Float {
        return self.size.height
    }

}

public extension Rect {
    
    func applying(_ transform: Transform2D) -> Rect {
        if transform == .identity {
            return self
        }

        let upLeft = Point(x: minX, y: minY).applying(transform)
        let upRight = Point(x: maxX, y: minY).applying(transform)
        let downLeft = Point(x: minX, y: maxY).applying(transform)
        let downRight = Point(x: maxX, y: maxY).applying(transform)

        let minX = min(upLeft.x, upRight.x, downLeft.x, downRight.x)
        let maxX = max(upLeft.x, upRight.x, downLeft.x, downRight.x)

        let minY = min(upLeft.y, upRight.y, downLeft.y, downRight.y)
        let maxY = max(upLeft.y, upRight.y, downLeft.y, downRight.y)

        return Rect(
            x: minX,
            y: minY,
            width: maxX - minX, 
            height: maxY - minY
        )
    }

    func contains(point: Point) -> Bool {
        point.x >= self.minX && point.x < self.maxX &&
        point.y >= self.minY && point.y < self.maxY
    }

    func intersects(_ other: Rect) -> Bool {
      return self.minX <= other.maxX
              && other.minX <= self.maxX
              && self.minY <= other.maxY
              && other.minY <= self.maxY
    }
}
