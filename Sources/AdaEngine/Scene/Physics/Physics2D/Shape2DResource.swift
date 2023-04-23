//
//  Shape2DResource.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

// TODO: (Vlad) Add hashable and equatable and resource
// TODO: (Vlad) Looks like we should share resources in ECS world

/// A representation of a shape.
public final class Shape2DResource: Codable {
    
    struct CircleShape: Codable {
        let radius: Float
        var offset: Vector2 = .zero
    }
    
    struct BoxShape: Codable {
        let halfWidth: Float
        let halfHeight: Float
        var offset: Vector2 = .zero
    }
    
    struct PolygonShape: Codable {
        let verticies: [Vector2]
        var offset: Vector2 = .zero
    }
    
    enum Fixture: Codable {
        case circle(CircleShape)
        case box(BoxShape)
        case polygon(PolygonShape)
    }
    
    let fixture: Fixture
    
    init(fixture: Fixture) {
        self.fixture = fixture
    }
    
    /// Creates a circle shape with the specified radius.
    public static func generateCircle(radius: Float) -> Shape2DResource {
        return Shape2DResource(fixture: .circle(CircleShape(radius: radius)))
    }
    
    /// Creates a box shape with the specified size. By default size is equal entity transformation scale value.
    public static func generateBox(width: Float = 1, height: Float = 1) -> Shape2DResource {
        return Shape2DResource(fixture: .box(BoxShape(halfWidth: width / 2, halfHeight: height / 2)))
    }
    
    /// Creates a box shape with the specified size and rotation.
    /// By default size is equal entity transformation scale value.
    public static func generateBox(width: Float = 1, height: Float = 1, center: Vector2, angle: Float) -> Shape2DResource {
        return Shape2DResource(fixture: .box(BoxShape(halfWidth: width / 2, halfHeight: height / 2, offset: center)))
    }
    
    /// Create a custom polygon shape.
    public static func generatePolygon(vertices: [Vector2]) -> Shape2DResource {
        return Shape2DResource(fixture: .polygon(PolygonShape(verticies: vertices)))
    }
    
    /// Creates a new shape resource by applying a rotation.
    public func offsetBy(x: Float, y: Float) -> Shape2DResource {
        switch self.fixture {
        case .box(var shape):
            shape.offset = [x, y]
            
            return Shape2DResource(fixture: .box(shape))
        case .circle(var shape):
            shape.offset = [x, y]
            
            return Shape2DResource(fixture: .circle(shape))
        case .polygon(var shape):
            shape.offset = [x, y]
            
            return Shape2DResource(fixture: .polygon(shape))
        }
    }
}
