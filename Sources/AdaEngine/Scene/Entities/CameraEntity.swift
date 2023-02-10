//
//  CameraEntity.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/10/23.
//

public class CameraEntity: Entity {
    public override init(name: String = "CameraEntity") {
        super.init(name: name)
        
        self.components += Camera()
        self.components += VisibleEntities(entities: [])
    }
}
