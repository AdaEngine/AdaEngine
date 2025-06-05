//
//  RenderNode.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/18/23.
//

/// A render node that can be added to a ``RenderGraph``.
///
/// Nodes are the fundamental part of the graph and used to extend its functionality, by
/// generating draw calls and/or running subgraphs.
public protocol RenderNode: Sendable {

    typealias Context = RenderGraphContext
    
    /// Specifies the required input slots for this node.
    var inputResources: [RenderSlot] { get }
    
    /// Specifies the produced output slots for this node.
    var outputResources: [RenderSlot] { get }

    /// Runtime key for link slot and node together.
    static var name: String { get }

    /// Execute the graph node logic, issues draw calls, updates the output slots and optionally queues up subgraphs for execution. The graph data, input and output values are
    /// passed via the ``RenderGraphContext``.
    @RenderGraphActor func execute(context: inout Context) async throws -> [RenderSlotValue]
}

public extension RenderNode {
    static var name: String {
        String(describing: self)
    }
}

public extension RenderNode {
    var inputResources: [RenderSlot] {
        return []
    }
    
    var outputResources: [RenderSlot] {
        return []
    }
}

public struct EmptyRenderNode: RenderNode {
    public func execute(context: inout Context) async throws -> [RenderSlotValue] {
        return []
    }
}
