//
//  SystemsGraph.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import OrderedCollections

/// Contains information about execution order of systems.
public struct SystemsGraph: Sendable, ~Copyable {

    /// Indicates that graph is changed and needs recalculate deps
    private(set) var isChanged: Bool = false

    /// The edge of the systems graph.
    struct Edge: Equatable {
        /// The output node of the edge.
        let outputNode: String
        
        /// The input node of the edge.
        let inputNode: String
    }
    
    /// The node of the systems graph.
    struct Node: Sendable {
        /// The unique identifier of the node.
        typealias ID = String
        
        /// The name of the node.
        let name: String
        
        /// The system of the node.
        var system: System
        
        /// The dependencies of the node.
        var dependencies: [SystemDependency]
        
        /// The input edges of the node.
        var inputEdges: [Edge] = []
        
        /// The output edges of the node.
        var outputEdges: [Edge] = []
    }
    
    /// The systems of the graph.
    var systems: [System] {
        self.nodes.values.elements.map { $0.system }
    }
    
    private(set) var dependencyLevels: [[SystemsGraph.Node]] = []
    
    /// The nodes of the graph.
    private(set) var nodes: OrderedDictionary<String, Node> = [:]
    
    /// Initialize a new systems graph.
    public init() { }
    
    // MARK: - Internal methods
    
    /// Add a node of the current system. If a node exists with the same type, it will be overridden.
    /// - Note: Systems will be added with nodes without edges.
    /// - Parameter system: The system to add.
    mutating func addSystem<T: System>(_ system: T) {
        self.isChanged = true
        let node = Node(name: T.swiftName, system: system, dependencies: T.dependencies)
        self.nodes[node.name] = node
    }
    
    /// Create an execution order for all systems.
    /// - Complexity: O(n^2)
    mutating func linkSystems() {
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
        
        self.dependencyLevels = self.buildDependencyLevels()
        self.isChanged = false
    }
    
    /// Get the output nodes for a given node.
    /// - Parameter nodeId: The ID of the node.
    /// - Returns: The output nodes for the given node.
    /// - Complexity: O(n)
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
    
    /// Get the input nodes for a given node.
    /// - Parameter nodeId: The ID of the node.
    /// - Returns: The input nodes for the given node.
    /// - Complexity: O(n)
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
    
    /// Try to add an edge. If a dependency is cycled, it will be skipped with an error.
    /// - Parameter outputSystemName: The name of the output system.
    /// - Parameter inputSystemName: The name of the input system.
    private mutating func tryAddEdge(from outputSystemName: String, to inputSystemName: String) {
        var outputNode = self.nodes[outputSystemName]
        var inputNode = self.nodes[inputSystemName]
        
        assert(outputNode != nil, "[SystemsGraph] System not exists \(outputSystemName) to \(inputSystemName)")
        assert(inputNode != nil, "[SystemsGraph] System not exists \(inputSystemName) for \(outputSystemName)")
        
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
    
    /// Validate an edge.
    /// - Parameter edge: The edge to validate.
    /// - Parameter shouldExists: Whether the edge should exist.
    /// - Returns: True if the edge is valid, otherwise false.
    private func validateEdge(_ edge: Edge, shouldExists: Bool) -> Bool {
        if shouldExists {
            return hasEdge(edge)
        } else {
            return !hasEdge(edge)
        }
    }
    
    /// Check if an edge exists.
    /// - Parameter edge: The edge to check.
    /// - Returns: True if the edge exists, otherwise false.
    private func hasEdge(_ edge: Edge) -> Bool {
        guard let inputNode = self.nodes[edge.inputNode], let outputNode = self.nodes[edge.outputNode] else {
            return false
        }
        
        return inputNode.inputEdges.firstIndex(of: edge) != nil && outputNode.outputEdges.firstIndex(of: edge) != nil
    }
    
    /// Build dependency levels for systems to enable parallel execution of independent systems
    private func buildDependencyLevels() -> [[SystemsGraph.Node]] {
        var levels: [[SystemsGraph.Node]] = []
        var remainingNodes = Set(nodes.values.elements.map { $0.name })
        var processedNodes: Set<String> = []
        
        while !remainingNodes.isEmpty {
            var currentLevel: [SystemsGraph.Node] = []
            
            // Find all nodes that have no unprocessed dependencies
            for nodeName in remainingNodes {
                guard let node = nodes[nodeName] else { continue }
                
                let inputNodes = getInputNodes(for: nodeName)
                let hasUnprocessedDependencies = inputNodes.contains { inputNode in
                    !processedNodes.contains(inputNode.name)
                }
                
                if !hasUnprocessedDependencies {
                    currentLevel.append(node)
                }
            }
            
            // If no nodes can be processed, there might be a circular dependency
            guard !currentLevel.isEmpty else {
                fatalError("Circular dependency detected in systems graph")
            }
            
            // Update tracking sets
            for node in currentLevel {
                remainingNodes.remove(node.name)
                processedNodes.insert(node.name)
            }
            
            levels.append(currentLevel)
        }
        
        return levels
    }
}

extension SystemsGraph {
    /// The debug description of the systems graph.
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
    
    /// The visualize description of the systems graph.
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
