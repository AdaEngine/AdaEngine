//
//  BatchTransparent2DItemsSystem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import AdaECS

/// Batch transparent items which contains batchEntity.
/// Run each frame before drawing.
@PlainSystem
public struct BatchTransparent2DItemsSystem {

    @Query<Ref<RenderItems<Transparent2DRenderItem>>>
    private var query

    public init(world: World) { }

    public func update(context: UpdateContext) {
        self.query.forEach { renderItems in
            let items = renderItems.wrappedValue.sorted().items
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
            
            renderItems.items = batchedItems
        }
    }
    
    private func tryToAddBatch(to currentItem: inout Transparent2DRenderItem, from otherItem: Transparent2DRenderItem) -> Bool {
        guard let batch = currentItem.batchRange, let otherBatch = otherItem.batchRange else {
            return false
        }
        
        if otherItem.batchEntity != currentItem.batchEntity {
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
