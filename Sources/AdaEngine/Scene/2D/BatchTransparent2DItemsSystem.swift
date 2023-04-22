//
//  BatchTransparent2DItemsSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

/// Batch transparent items which contains batchEntity.
/// Run each frame before drawing.
public struct BatchTransparent2DItemsSystem: System {
    
    public static var dependencies: [SystemDependency] = [.after(CameraSystem.self), .after(VisibilitySystem.self)]

    static let query = EntityQuery(where: .has(RenderItems<Transparent2DRenderItem>.self))

    public init(scene: Scene) { }

    public func update(context: UpdateContext) {
        context.scene.performQuery(Self.query).forEach { entity in
            guard let renderItems = entity.components[RenderItems<Transparent2DRenderItem>.self] else {
                return
            }
            
            let items = renderItems.items
            var batchedItems: [Transparent2DRenderItem] = []
            batchedItems.reserveCapacity(items.count)
            
            if var currentItem = items.first {
                for nextItemIndex in 1..<items.count {
                    let nextItem = items[nextItemIndex]
                    
                    if tryToAddBatch(to: &currentItem, from: nextItem) == false {
                        batchedItems.append(currentItem)
                        currentItem = nextItem
                    }
                }
                
                batchedItems.append(currentItem)
            }
            
            entity.components[RenderItems<Transparent2DRenderItem>.self] = RenderItems(items: batchedItems)
        }
    }
    
    private func tryToAddBatch(to currentItem: inout Transparent2DRenderItem, from otherItem: Transparent2DRenderItem) -> Bool {
        guard let batch = currentItem.batchRange, let otherBatch = otherItem.batchRange else {
            return false
        }
        
        if otherItem.batchEntity.id != currentItem.batchEntity.id {
            return false
        }
        
        if batch.upperBound == otherBatch.lowerBound {
            currentItem.batchRange = batch.lowerBound ..< otherBatch.upperBound
        } else if batch.lowerBound == otherBatch.upperBound {
            currentItem.batchRange = otherBatch.lowerBound ..< batch.upperBound
        } else {
            return false
        }
        
        return true
    }
}
