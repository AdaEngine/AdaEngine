//
//  SystemsGraph.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import OrderedCollections

class SystemsGraph {
    
    struct Edge: Equatable {
        let outputNode: String
        let inputNode: String
    }
    
    struct Node {
        
        typealias ID = String
        
        let name: String
        let system: System
        var dependencies: [SystemDependency]
        
        var inputEdges: [Edge] = []
        var outputEdges: [Edge] = []
    }
    
    private(set) var nodes: OrderedDictionary<String, Node> = [:]
    
    func addSystem<T: System>(_ system: T) {
        let node = Node(name: T.swiftName, system: system, dependencies: T.dependencies)
        self.nodes[node.name] = node
    }
    
    func linkSystems() {
        for node in nodes.values {
            let systemName = node.name
            print(systemName)
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
    
    // MARK: - Private
    
    private func tryAddEdge(from outputSystemName: String, to inputSystemName: String) {
        var outputNode = self.nodes[outputSystemName]
        var inputNode = self.nodes[inputSystemName]
        
        assert(outputNode != nil, "[SystemsGraph] System not exists \(outputSystemName)")
        assert(inputNode != nil, "[SystemsGraph] System not exists \(inputSystemName)")
        
        let edge = Edge(outputNode: outputSystemName, inputNode: inputSystemName)
        
        guard self.validateEdge(edge, shouldExists: false) else {
            return
        }
        
        outputNode?.outputEdges.append(edge)
        inputNode?.inputEdges.append(edge)
        
        self.nodes[inputSystemName] = inputNode
        self.nodes[outputSystemName] = outputNode
    }
    
    private func validateEdge(_ edge: Edge, shouldExists: Bool) -> Bool {
        if shouldExists && self.hasEdge(edge) {
            return false
        }
        
        return true
    }
    
    private func hasEdge(_ edge: Edge) -> Bool {
        guard let inputNode = self.nodes[edge.inputNode], let outputNode = self.nodes[edge.outputNode] else {
            return false
        }
        
        return inputNode.inputEdges.firstIndex(of: edge) != nil && outputNode.outputEdges.firstIndex(of: edge) != nil
    }
    
}
