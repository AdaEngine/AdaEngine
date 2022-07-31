//
//  Shape2DResource.swift
//  
//
//  Created by v.prusakov on 7/11/22.
//

import box2d

// TODO: Add hashable and equatable and resource
// TODO: Looks like we should share resources in ECS world
public final class Shape2DResource {
    
    let fixtureDef: b2FixtureDef
    
    init(fixtureDef: b2FixtureDef) {
        self.fixtureDef = fixtureDef
    }
    
    public static func generateCircle(radius: Float) -> Shape2DResource {
        let shape = b2CircleShape()
        shape.radius = radius
        
        let fixtureDef = b2FixtureDef()
        fixtureDef.shape = shape
        
        return Shape2DResource(fixtureDef: fixtureDef)
    }
    
    public static func generateBox(width: Float, height: Float) -> Shape2DResource {
        let shape = b2PolygonShape()
        shape.setAsBox(halfWidth: width, halfHeight: height)
        
        let fixtureDef = b2FixtureDef()
        fixtureDef.shape = shape
        
        return Shape2DResource(fixtureDef: fixtureDef)
    }
    
    public static func generateBox(width: Float, height: Float, center: Vector2, angle: Float) -> Shape2DResource {
        let shape = b2PolygonShape()
        shape.setAsBox(halfWidth: width, halfHeight: height, center: center.b2Vec, angle: angle)
        
        let fixtureDef = b2FixtureDef()
        fixtureDef.shape = shape
        
        return Shape2DResource(fixtureDef: fixtureDef)
    }
    
    public static func generatePolygon(vertices: [Vector2]) -> Shape2DResource {
        let shape = b2PolygonShape()
        shape.set(vertices: unsafeBitCast(vertices, to: [b2Vec2].self))
        
        let fixtureDef = b2FixtureDef()
        fixtureDef.shape = shape
        
        return Shape2DResource(fixtureDef: fixtureDef)
    }
}
