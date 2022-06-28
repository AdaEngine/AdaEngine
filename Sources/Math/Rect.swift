//
//  Rect.swift
//  
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
    static let zero = Rect(origin: .zero, size: .zero)
    
    init(x: Float, y: Float, width: Float, height: Float) {
        self.origin = [x, y]
        self.size = Size(width: width, height: height)
    }
}

public extension Rect {

    // FIXME: Not work correctly in affine space
    func applying(_ transform: Transform2D) -> Rect {
        let size = Vector2(size.width, size.height)
        
        let upLeft = self.origin.applying(transform)
        let downLeft = Point(self.origin.y, self.maxY).applying(transform)
        let upRight = Point(self.origin.x, self.maxX).applying(transform)
        let downRight = Point(self.maxX, self.maxY).applying(transform)
        
        return Rect(x: upLeft.x, y: upLeft.y, width: downLeft.x - downRight.x, height: downLeft.y - downRight.y)
    }
    
    func contains(point: Point) -> Bool {
        point.x >= self.minX && point.x <= self.maxX &&
        point.y >= self.minY && point.y <= self.maxY
    }
    
    var minX: Float {
        return self.origin.x
    }
    
    var maxX: Float {
        return self.origin.x + self.size.width
    }
    
    var midX: Float {
        return self.size.width / 2 + self.origin.x
    }
    
    var minY: Float {
        return self.origin.y
    }
    
    var maxY: Float {
        return self.origin.y + self.size.height
    }
    
    var midY: Float {
        return self.size.height / 2 + self.origin.y
    }
}
