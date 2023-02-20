//
//  RenderGraph.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/15/23.
//

// Inspired by Bevy https://github.com/bevyengine/bevy/tree/main/crates/bevy_render/src/render_graph

public struct RenderSlot {
    public let name: String
    public let kind: RenderResourceKind
}

public struct RenderSlotValue {
    public let name: String
    public let value: RenderResource
}

enum Edge: Equatable, Hashable {
    case slot(outputNode: String, outputSlotIndex: Int, inputNode: String, inputSlotIndex: Int)
    case node(outputNode: String, inputNode: String)
    
    var inputNode: String {
        switch self {
        case let .node(_, inputNode):
            return inputNode
        case let .slot(_, _, inputNode, _):
            return inputNode
        }
    }
    
    var outputNode: String {
        switch self {
        case let .node(outputNode, _):
            return outputNode
        case let .slot(outputNode, _, _, _):
            return outputNode
        }
    }
}

struct EmptyNode: RenderNode {
    func execute(context: Context) -> [RenderSlotValue] {
        return []
    }
}

struct GraphEntryNode: RenderNode {
    
    var inputResources: [RenderSlot]
    var outputResources: [RenderSlot]
    
    init(inputResources: [RenderSlot]) {
        self.inputResources = inputResources
        self.outputResources = inputResources
    }
    
    func execute(context: Context) -> [RenderSlotValue] {
        return context.inputResources
    }
}

// Inspired by Bevy Render Graph

public final class RenderGraph {
    
    static let entryNodeName: String = "_GraphEntryNode"
    
    struct Node {
        
        typealias ID = String
        
        let name: String
        let node: RenderNode
        
        var inputEdges: [Edge] = []
        var outputEdges: [Edge] = []
    }
    
    internal private(set) var nodes: [Node.ID: Node] = [:]
    internal private(set) var subGraphs: [String: RenderGraph] = [:]
    
    internal private(set) var entryNode: Node?
    
    public func addEntryNode(inputs: [RenderSlot]) -> String {
        let node = GraphEntryNode(inputResources: inputs)
        let renderNode = Node(name: Self.entryNodeName, node: node)
        self.nodes[Self.entryNodeName] = renderNode
        self.entryNode = renderNode
        
        return Self.entryNodeName
    }
    
    public func addNode(with name: String, node: RenderNode) {
        self.nodes[name] = Node(name: name, node: node)
    }
    
    public func addSlotEdge(
        fromNode outputNodeName: String,
        outputSlot: String,
        toNode inputNodeName: String,
        inputSlot: String
    ) {
        let oNode = self.nodes[outputNodeName]
        let iNode = self.nodes[inputNodeName]
        assert(oNode != nil, "Can't find node by name \(outputNodeName)")
        assert(iNode != nil, "Can't find node by name \(inputNodeName)")
        guard var iNode, var oNode else {
            return
        }
        
        let outputSlotIndex = oNode.node.outputResources.firstIndex(where: { $0.name == outputSlot })
        let inputSlotIndex = iNode.node.inputResources.firstIndex(where: { $0.name == inputSlot })
        
        assert(outputSlotIndex != nil, "Can't find slot by name \(outputSlot)")
        assert(inputSlotIndex != nil, "Can't find slot by name \(inputSlot)")
        
        guard var outputSlotIndex, var inputSlotIndex else {
            return
        }
        
        let edge = Edge.slot(outputNode: outputNodeName, outputSlotIndex: outputSlotIndex, inputNode: inputNodeName, inputSlotIndex: inputSlotIndex)
        
        guard self.validateEdge(edge, shouldExsits: false) else {
            return
        }
        
        oNode.outputEdges.append(edge)
        iNode.inputEdges.append(edge)
        
        self.nodes[outputNodeName] = oNode
        self.nodes[inputNodeName] = iNode
    }
    
    public func addNodeEdge(from outputNodeName: String, to inputNodeName: String) {
        let oNode = self.nodes[outputNodeName]
        let iNode = self.nodes[inputNodeName]
        assert(oNode != nil, "Can't find node by name \(outputNodeName)")
        assert(iNode != nil, "Can't find node by name \(inputNodeName)")
        guard var iNode, var oNode else {
            return
        }
        
        let edge = Edge.node(outputNode: outputNodeName, inputNode: inputNodeName)
        
        oNode.outputEdges.append(edge)
        iNode.inputEdges.append(edge)
        
        self.nodes[outputNodeName] = oNode
        self.nodes[inputNodeName] = iNode
    }
    
    public func removeNode(by name: String) -> Bool {
        guard let node = self.nodes.removeValue(forKey: name) else {
            // Node not exists
            return false
        }
        
        for edge in node.inputEdges {
            self.nodes[edge.outputNode]?.outputEdges.removeAll(where: { edge == $0 })
        }
        
        for edge in node.outputEdges {
            self.nodes[edge.inputNode]?.inputEdges.removeAll(where: { edge == $0 })
        }
        
        return true
    }
    
    public func removeSlotEdge(
        fromNode outputNodeName: String,
        outputSlot: String,
        toNode inputNodeName: String,
        inputSlot: String
    ) -> Bool {
        guard
            var oNode = self.nodes[outputNodeName],
            var iNode = self.nodes[inputNodeName],
            let outputSlotIndex = oNode.node.outputResources.firstIndex(where: { $0.name == outputNodeName }),
            let inputSlotIndex = iNode.node.inputResources.firstIndex(where: { $0.name == inputNodeName })
        else {
            return false
        }
        
        let edge = Edge.slot(outputNode: outputNodeName, outputSlotIndex: outputSlotIndex, inputNode: inputNodeName, inputSlotIndex: inputSlotIndex)
        
        if !self.hasEdge(edge) {
            return false
        }
        
        oNode.outputEdges.removeAll(where: { $0 == edge })
        iNode.inputEdges.removeAll(where: { $0 == edge })
        
        self.nodes[outputNodeName] = oNode
        self.nodes[inputNodeName] = iNode
        
        return true
    }
    
    public func addSubgraph(_ graph: RenderGraph, name: String) {
        self.subGraphs[name] = graph
    }
    
    // MARK: Private
    
    internal func getOutputNodes(for node: Node.ID) -> [(Edge, Node)] {
        guard let node = self.nodes[node] else {
            return []
        }
        
        return node.outputEdges.compactMap { edge in
            guard let node = self.nodes[edge.inputNode] else {
                return nil
            }
            
            return (edge, node)
        }
    }
    
    internal func getInputNodes(for node: Node.ID) -> [(Edge, Node)] {
        guard let node = self.nodes[node] else {
            return []
        }
        
        return node.inputEdges.compactMap { edge in
            guard let node = self.nodes[edge.outputNode] else {
                return nil
            }
            
            return (edge, node)
        }
    }
    
    private func hasEdge(_ edge: Edge) -> Bool {
        switch edge {
        case .slot(let outputNode, _, let inputNode, _):
            guard let oNode = self.nodes[outputNode], let iNode = self.nodes[inputNode] else {
                return false
            }
            
            return oNode.outputEdges.firstIndex(of: edge) != nil && iNode.inputEdges.firstIndex(of: edge) != nil
        case .node(let outputNode, let inputNode):
            guard let oNode = self.nodes[outputNode], let iNode = self.nodes[inputNode] else {
                return false
            }
            
            return oNode.outputEdges.firstIndex(of: edge) != nil && iNode.inputEdges.firstIndex(of: edge) != nil
        }
    }
    
    // TODO: (Vlad) Throw errors?
    private func validateEdge(_ edge: Edge, shouldExsits: Bool) -> Bool {
        if shouldExsits && self.hasEdge(edge) {
            return false
        }
        
        // We should validate only slots
        guard case .slot(let outputNode, let outputSlotIndex, let inputNode, let inputSlotIndex) = edge else {
            return true
        }
        
        guard let oNode = self.nodes[outputNode], let iNode = self.nodes[inputNode] else {
            // Nodes not exists
            return false
        }
        
        let outputSlot = oNode.node.outputResources[outputSlotIndex]
        let inputSlot = iNode.node.inputResources[inputSlotIndex]
        
        let isSlotConnected = iNode.inputEdges.contains(where: { edge in
            guard case .slot(_, _, _, let slotIndex) = edge else {
                return false
            }
            
            return slotIndex == outputSlotIndex
        })
        
        if isSlotConnected && !shouldExsits {
            // Slot already connected
            return false
        }
        
        if outputSlot.kind != inputSlot.kind {
            // Mismatched types
            return false
        }
        
        return true
    }
    
}
