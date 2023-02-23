//
//  ClearTransparent2DRenderItemsSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

public struct ClearTransparent2DRenderItemsSystem: System {
    
    public static var dependencies: [SystemDependency] = [.before(SpriteRenderSystem.self)]
    
    static let query = EntityQuery(where: .has(RenderItems<Transparent2DRenderItem>.self))
    
    public init(scene: Scene) { }
    
    public func update(context: UpdateContext) {
//        context.scene.performQuery(Self.query).forEach { entity in
//            entity.components[RenderItems<Transparent2DRenderItem>.self]?.items.removeAll()
//        }
    }
}
