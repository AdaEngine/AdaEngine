//
//  DrawPass.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

/// The context with information required to run a ``DrawPass``.
public struct RenderContext {
    public let device: RenderDevice
    public let entity: Entity
    public let world: World
    public let view: Entity
    public let drawList: DrawList
}

public struct DrawPassId: Equatable, Hashable, Sendable {
    let id: Int
}

/// Draw pass is a render function that will render for specific item.
///
/// For example, you can create render pass for rendering ``Transparent2DRenderItem`` and configure rendering whatever you want. 
/// Pass additional render data as components to ``Entity`` and pass that entity to ``Transparent2DRenderItem/entity`` property.
public protocol DrawPass<Item> {
    associatedtype Item: RenderItem
    typealias Context = RenderContext

    @MainActor
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
    let base: any DrawPass
    
    public init<Value: DrawPass>(_ base: Value) {
        self.base = base
    }
    
    public func render(in context: Context, item: T) throws {
        try base._render(in: context, item: item)
    }
}

private extension DrawPass {
    @MainActor func _render(in context: Context, item: Any) throws {
        try self.render(in: context, item: item as! Self.Item)
    }
}
