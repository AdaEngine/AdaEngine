//
//  RenderItem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

public struct RenderItems<T: RenderItem>: Component {
    public var items: [T]
    
    public init(items: [T] = []) {
        self.items = items
    }
    
    public mutating func sort() {
        self.items.sort(by: { $0.sortKey < $1.sortKey })
    }
    
    public func sorted() -> Self {
        var value = self
        value.items.sort(by: { $0.sortKey < $1.sortKey })
        return value
    }
    
    public func render(_ drawList: DrawList, world: World, view: Entity) throws {
        for item in self.items {
            guard let drawPass = DrawPassStorage.getDrawPass(for: item) else {
                continue
            }
            
            let context = RenderContext(
                device: .shared,
                entity: item.entity,
                world: world,
                view: view,
                drawList: drawList
            )
            
            try drawPass.render(in: context, item: item)
            
            drawList.clear()
        }
    }
}

public protocol RenderItem {
    
    associatedtype SortKey: Comparable
    
    var entity: Entity { get }
    var drawPassId: DrawPassId { get }
    var sortKey: SortKey { get }
}
