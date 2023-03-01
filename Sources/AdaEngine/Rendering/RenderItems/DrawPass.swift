//
//  DrawPass.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

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
