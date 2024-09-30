//
//  RenderItem.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

/// An object that store render items for rendering.
@Component
public struct RenderItems<T: RenderItem> {
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
    
    @MainActor
    public func render(_ renderCommandEncoder: RenderCommandEncoder, device: RenderingDevice, world: World, view: Entity) throws {
        for item in self.items {
            guard let drawPass = DrawPassStorage.getDrawPass(for: item) else {
                continue
            }
            
            let context = DrawPassRenderContext(
                device: device,
                entity: item.entity,
                world: world,
                view: view,
                renderEncoder: renderCommandEncoder
            )
            try drawPass.render(in: context, item: item)
        }
    }
}

public protocol RenderItem {
    associatedtype SortKey: Comparable
    
    var entity: Entity { get }
    var drawPassId: DrawPassId { get }
    var sortKey: SortKey { get }
}
