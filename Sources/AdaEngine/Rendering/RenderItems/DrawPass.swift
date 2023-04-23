//
//  DrawPass.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

/// The context with information required to run a ``DrawPass``.
public struct RenderContext {
    public let device: RenderEngine
    public let entity: Entity
    public let world: World
    public let view: Entity
    public let drawList: DrawList
}

public struct DrawPassId: Equatable, Hashable {
    let id: Int
}

/// Draw pass is a render function that will render for specific item.
///
/// For example, you can create render pass for rendering ``Transparent2DRenderItem`` and configure rendering whatever you want. Pass additional render data as components to ``Entity`` and pass that entity to ``Transparent2DRenderItem/entity`` property.
public protocol DrawPass<Item> {
    
    associatedtype Item: RenderItem
    typealias Context = RenderContext
    
    func render(in context: Context, item: Item) throws
}

public extension DrawPass {
    /// Return identifier of draw pass based on DrawPass.Type
    @inline(__always) static var identifier: DrawPassId {
        DrawPassId(id: Int(bitPattern: ObjectIdentifier(self)))
    }
}

/// Type-erased draw pass.
public struct AnyDrawPass<T: RenderItem>: DrawPass {
    
    private var render: (Context, Any) throws -> Void
    
    public init<Value: DrawPass>(_ base: Value) {
        self.render = { context, item in
            try base.render(in: context, item: item as! Value.Item)
        }
    }
    
    public func render(in context: Context, item: T) throws {
        try render(context, item)
    }
}
