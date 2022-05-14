//
//  ViewContainerComponent.swift
//  
//
//  Created by v.prusakov on 5/11/22.
//

@_exported import Math

public typealias Point = Vector2

public struct ViewContrainerComponent: Component {
    public var rootView: View
    
    public init(rootView: View) {
        self.rootView = rootView
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError()
    }
    
    public init(from decoder: Decoder) throws {
        fatalError()
    }
}

public struct Size: Equatable, Codable, Hashable {
    public var width: Float
    public var height: Float
    
    public static let zero = Size(width: 0, height: 0)
}

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
        !(point.x < self.minX || point.x > self.maxX ||
        point.y < self.minX || point.y > self.maxY)
    }
    
    var minX: Float {
        return self.origin.x
    }
    
    var maxX: Float {
        return self.size.width
    }
    
    var midX: Float {
        return self.maxX / 2
    }
    
    var minY: Float {
        return self.origin.y
    }
    
    var maxY: Float {
        return self.size.height
    }
    
    var midY: Float {
        return self.maxY / 2
    }
}
