//
//  RenderGraph.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/15/23.
//

// Inspired by Bevy Render Graph

public protocol RenderNode {
    
    typealias Context = RenderGraphContext
    
    var name: String { get }
    
    var inputResources: [RenderSlot] { get }
    var outputResources: [RenderSlot] { get }
    
    func execute(context: Context) -> [RenderSlotValue]
}

public enum RenderResource {
    case texture(Texture)
    case buffer(Buffer)
    case sampler(Sampler)
    case entity(Entity)
}

public extension RenderResource {
    var resourceKind: RenderResourceKind {
        switch self {
        case .texture:
            return .texture
        case .buffer:
            return .buffer
        case .sampler:
            return .sampler
        case .entity:
            return .entity
        }
    }
    
    var texture: Texture? {
        guard case .texture(let texture) = self else {
            return nil
        }
        
        return texture
    }
    
    var buffer: Buffer? {
        guard case .buffer(let buffer) = self else {
            return nil
        }
        
        return buffer
    }
    
    var sampler: Sampler? {
        guard case .sampler(let sampler) = self else {
            return nil
        }
        
        return sampler
    }
    
    var entity: Entity? {
        guard case .entity(let entity) = self else {
            return nil
        }
        
        return entity
    }
}

public enum RenderResourceKind {
    case texture
    case buffer
    case sampler
    case entity
}

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

struct GraphEntryNode: RenderNode {
    
    var name: String = RenderGraph.entryNodeName
    
    var inputResources: [RenderSlot] = []
    var outputResources: [RenderSlot] = []
    
    func execute(context: Context) -> [RenderSlotValue] {
        return context.inputResources
    }
}

public final class RenderGraph {
    
    static let entryNodeName: String = "_GraphEntryNode"
    
    struct Node {
        
        typealias ID = String
        
        let name: String
        let node: RenderNode
        
        var inputEdges: [Edge] = []
        var outputEdges: [Edge] = []
    }
    
    internal var nodes: [Node.ID: Node] = [:]
    
    internal var entryNode: Node?
    
    public func addEntry(inputs: [RenderSlot]) {
        let node = GraphEntryNode(name: Self.entryNodeName, inputResources: inputs, outputResources: inputs)
        let renderNode = Node(name: Self.entryNodeName, node: node)
        self.nodes[Self.entryNodeName] = renderNode
        self.entryNode = renderNode
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
        assert(oNode == nil, "Can't find node by name \(outputNodeName)")
        assert(iNode == nil, "Can't find node by name \(inputNodeName)")
        guard var iNode, var oNode else {
            return
        }
        
        let outputSlotIndex = oNode.node.outputResources.firstIndex(where: { $0.name == outputSlot })
        let inputSlotIndex = iNode.node.inputResources.firstIndex(where: { $0.name == inputSlot })
        
        assert(outputSlotIndex == nil, "Can't find slot by name \(outputSlot)")
        assert(inputSlotIndex == nil, "Can't find slot by name \(inputSlot)")
        
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
        assert(oNode == nil, "Can't find node by name \(outputNodeName)")
        assert(iNode == nil, "Can't find node by name \(inputNodeName)")
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
    
    // MARK: Private
    
    func getOutputNodes(for node: Node.ID) -> [(Edge, Node)] {
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
    
    func getInputNodes(for node: Node.ID) -> [(Edge, Node)] {
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

import Collections

public struct RenderGraphContext {
    public internal(set) var inputResources: [RenderSlotValue]
}

public class RenderGraphExecutor {
    public func executeGraph(_ graph: RenderGraph, inputResources: [RenderSlotValue]) {
        
        var writtenResources = [RenderGraph.Node.ID: [RenderSlotValue]]()
        
        /// Should execute firsts
        var nodes: Deque<RenderGraph.Node> = Deque(graph.nodes.filter { $0.value.inputEdges.isEmpty }.values)
        
        if let entryNode = graph.entryNode {
            for (index, inputSlot) in entryNode.node.inputResources.enumerated() {
                let resource = inputResources[index]
                
                if resource.value.resourceKind != inputSlot.kind {
                    fatalError("Mismatched slot type")
                }
                   
            }
            
            writtenResources[entryNode.name] = inputResources
            
            for (_, node) in graph.getOutputNodes(for: entryNode.name) {
                nodes.prepend(node)
            }
        }
        
        nextNode: while let node = nodes.popLast() {
            // if we has a outputs for node we should skip it
            if writtenResources[node.name] != nil {
                continue
            }
            
            var inputSlots: [(Int, RenderSlotValue)] = []
            
            for (edge, inputNode) in graph.getInputNodes(for: node.name) {
                switch edge {
                case .slot(_, let outputSlotIndex, _, let inputSlotIndex):
                    if let outputs = writtenResources[inputNode.name] {
                        inputSlots.append(
                            (
                                inputSlotIndex,
                                outputs[outputSlotIndex]
                            )
                        )
                    } else {
                        nodes.prepend(node)
                        continue nextNode
                    }
                case .node:
                    if writtenResources[inputNode.name] != nil {
                        nodes.prepend(node)
                        continue nextNode
                    }
                }
            }
            let inputs = inputSlots.sorted(by: { $0.0 > $1.0 }).map { $0.1 }
            let context = RenderGraphContext(inputResources: inputs)
            let outputs = node.node.execute(context: context)
            
            
        }
    }
}
