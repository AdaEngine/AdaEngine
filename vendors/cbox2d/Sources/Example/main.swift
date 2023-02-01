//
//  File.swift
//  
//
//  Created by v.prusakov on 9/1/22.
//

import box2d
import AppKit

class View: NSView {
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let options = MTLResourceOptions()
        
        
    }
}

var def = b2BodyDef()
def.angle = 2

var gravity = b2Vec2(0, -9.8)
var world = b2World.init(gravity)
var body = world.CreateBody(&def)

print(body)

