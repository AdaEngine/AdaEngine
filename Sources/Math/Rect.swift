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
        var newRect = self
        newRect.origin.x += transform.position.x
        newRect.origin.y += transform.position.y
        return newRect
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
        return self.maxX / 2
    }
    
    var minY: Float {
        return self.origin.y
    }
    
    var maxY: Float {
        return self.origin.y + self.size.height
    }
    
    var midY: Float {
        return self.maxY / 2
    }
}
