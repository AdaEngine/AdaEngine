//
//  SystemsGraph.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import OrderedCollections

/// Contains information about execution order of systems.
@MainActor
public final class SystemsGraph {

    struct Edge: Equatable {
        let outputNode: String
        let inputNode: String
    }
    
    struct Node {
        
        typealias ID = String
        
        let name: String
        var system: System
        var dependencies: [SystemDependency]
        
        var inputEdges: [Edge] = []
        var outputEdges: [Edge] = []
    }
    
    var systems: [System] {
        self.nodes.values.elements.map { $0.system }
    }
    
    private(set) var nodes: OrderedDictionary<String, Node> = [:]
    
    // MARK: - Internal methods
    
    /// Add node of current system. If node exist with same type, than we will override it.
    /// - Note: Systems will added node without edges.
    func addSystem<T: System>(_ system: T) {
        let node = Node(name: T.swiftName, system: system, dependencies: T.dependencies)
        self.nodes[node.name] = node
    }
    
    /// Create an execution order for all systems.
    func linkSystems() {
        for node in nodes.values {
            let systemName = node.name
            
            for dependency in node.dependencies {
                switch dependency {
                case .after(let system):
                    self.tryAddEdge(from: system.swiftName, to: systemName)
                case .before(let system):
                    self.tryAddEdge(from: systemName, to: system.swiftName)
                }
            }
        }
    }
    
    func getOuputNodes(for nodeId: Node.ID) -> [Node] {
        guard let node = self.nodes[nodeId] else {
            return []
        }
        
        return node.outputEdges.compactMap { edge in
            guard let node = self.nodes[edge.inputNode] else {
                return nil
            }
            
            return node
        }
    }
    
    func getInputNodes(for nodeId: Node.ID) -> [Node] {
        guard let node = self.nodes[nodeId] else {
            return []
        }
        
        return node.inputEdges.compactMap { edge in
            guard let node = self.nodes[edge.outputNode] else {
                return nil
            }
            
            return node
        }
    }
    
    // MARK: - Private methods
    
    /// Try to add edge. If some dependency is cycled, than we will skip it with error
    private func tryAddEdge(from outputSystemName: String, to inputSystemName: String) {
        var outputNode = self.nodes[outputSystemName]
        var inputNode = self.nodes[inputSystemName]
        
        assert(outputNode != nil, "[SystemsGraph] System not exists \(outputSystemName)")
        assert(inputNode != nil, "[SystemsGraph] System not exists \(inputSystemName)")
        
        let edge = Edge(outputNode: outputSystemName, inputNode: inputSystemName)
        let reversedEdge = Edge(outputNode: inputSystemName, inputNode: outputSystemName)
        
        guard self.validateEdge(edge, shouldExists: false) && self.validateEdge(reversedEdge, shouldExists: false) else {
            assertionFailure("[SystemsGraph] Detected a cycle betweens \"\(outputSystemName)\" and \"\(inputSystemName)\"")
            return
        }
        
        outputNode?.outputEdges.append(edge)
        inputNode?.inputEdges.append(edge)
        
        self.nodes[inputSystemName] = inputNode
        self.nodes[outputSystemName] = outputNode
    }
    
    private func validateEdge(_ edge: Edge, shouldExists: Bool) -> Bool {
        if shouldExists {
            return hasEdge(edge)
        } else {
            return !hasEdge(edge)
        }
    }
    
    private func hasEdge(_ edge: Edge) -> Bool {
        guard let inputNode = self.nodes[edge.inputNode], let outputNode = self.nodes[edge.outputNode] else {
            return false
        }
        
        return inputNode.inputEdges.firstIndex(of: edge) != nil && outputNode.outputEdges.firstIndex(of: edge) != nil
    }
    
}

extension SystemsGraph: @preconcurrency CustomDebugStringConvertible {
    public var debugDescription: String {
        var string = ""
        for node in nodes.values.elements {
            string += "\(node.name)\n"
            
            string += " in: \n"
            for inputNode in getInputNodes(for: node.name) {
                string += "  \(node.name) --> \(inputNode.name)\n"
            }
            
            string += " out: \n"
            for ouputNode in getOuputNodes(for: node.name) {
                string += "  \(node.name) --> \(ouputNode.name)\n"
            }
        }
        
        return string
    }
    
    public var visualizeDescription: String {
        var string = ""
        for node in nodes.values.elements {
            for outputNode in getOuputNodes(for: node.name) {
                string += "\(node.name) --> \(outputNode.name)\n"
            }
        }
        return string
    }
}
