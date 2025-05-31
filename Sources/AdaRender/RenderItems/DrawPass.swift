//
//  DrawPass.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import AdaECS

/// The context with information required to run a ``DrawPass``.
public struct RenderContext {
    public let device: RenderDevice
    public let entity: Entity
    public let world: World
    public let view: Entity
    public let drawList: DrawList
}

/// Draw pass is a render function that will render for specific item.
///
/// For example, you can create render pass for rendering ``Transparent2DRenderItem`` and configure rendering whatever you want. 
/// Pass additional render data as components to ``Entity`` and pass that entity to ``Transparent2DRenderItem/entity`` property.
public protocol DrawPass<Item>: Resource {
    associatedtype Item: RenderItem
    typealias Context = RenderContext
    
    func render(in context: Context, item: Item) throws
}

/// Type-erased draw pass.
public struct AnyDrawPass<T: RenderItem>: DrawPass {
    let base: any DrawPass
    
    public init<Value: DrawPass>(_ base: Value) {
        self.base = base
    }
    
    public func render(in context: Context, item: T) throws {
        try base._render(in: context, item: item)
    }
}

private extension DrawPass {
    func _render(in context: Context, item: Any) throws {
        try self.render(in: context, item: item as! Self.Item)
    }
}
