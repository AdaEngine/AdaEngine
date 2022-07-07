//
//  PhysicsWorld2D.swift
//  
//
//  Created by v.prusakov on 7/6/22.
//

import box2d
import Math

public struct Body2D {
    unowned let world: PhysicsWorld2D
    
    var ref: OpaquePointer?
}

public final class PhysicsWorld2D {
    
    private var world: b2World
    
    public var velocityIterations: Int32 = 6
    public var positionIterations: Int32 = 2
    
    public var gravity: Vector2 {
        get {
            let vec = self.world.GetGravity()
            return [vec.x, vec.y]
        }
        
        set {
            var vec = b2Vec2(newValue.x, newValue.y)
            self.world.SetGravity(&vec)
        }
    }
    
    public init() {
        var vec = b2Vec2(0, 0)
        self.world = b2World(&vec)
    }
    
    public func updateSimulation(_ delta: Float) {
        self.world.Step(delta, self.velocityIterations, self.positionIterations)
    }
    
    public func createBody(position: Vector2, angle: Float) -> Body2D {
        var body2D = Body2D(world: self)
        
        var body = b2BodyDef()
        body.angle = angle
        body.position = b2Vec2(position.x, position.y)
        
        let ref = self.world.CreateBody(&body)
        body2D.ref = ref
        
        return body2D
    }
    
    public func destroyBody(_ body: Body2D) {
        self.world.DestroyBody(body.ref)
    }
}
