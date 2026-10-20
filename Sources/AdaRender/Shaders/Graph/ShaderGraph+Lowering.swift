extension ShaderGraph {
    /// Validates every authored node, then emits only computations reachable from the output.
    /// Scalar broadcasts are explicit in the IR; vectors and colors never implicitly change type.
    public func lowered() throws -> ShaderGraphIR {
        guard version == Self.currentVersion else {
            throw ShaderGraphDiagnostic(code: .unsupportedVersion)
        }
        let sortedNodes = nodes.sorted { $0.id < $1.id }
        var lookup: [String: Node] = [:]
        for node in sortedNodes {
            guard !node.id.isEmpty else {
                throw ShaderGraphDiagnostic(code: .invalidNodeID, nodeID: node.id)
            }
            guard lookup.updateValue(node, forKey: node.id) == nil else {
                throw ShaderGraphDiagnostic(code: .duplicateNode, nodeID: node.id)
            }
        }
        guard lookup[output]?.kind == Operation.output.rawValue else {
            throw ShaderGraphDiagnostic(code: .missingOutput, nodeID: output)
        }
        if let extra = sortedNodes.first(where: { $0.kind == Operation.output.rawValue && $0.id != output }) {
            throw ShaderGraphDiagnostic(code: .multipleOutputs, nodeID: extra.id)
        }

        var parameters: [String: Node] = [:]
        for node in sortedNodes {
            guard let operation = Operation(rawValue: node.kind) else {
                throw ShaderGraphDiagnostic(code: .unknownOperation, nodeID: node.id)
            }
            try validatePayload(node, operation: operation)
            if operation == .parameter, let reference = node.reference {
                if let previous = parameters[reference], previous.type != node.type || previous.value != node.value {
                    throw ShaderGraphDiagnostic(code: .conflictingParameter, nodeID: node.id, expected: previous.type, actual: node.type)
                }
                parameters[reference] = node
            }
        }
        var instructions: [String: ShaderGraphIR.Instruction] = [:]
        for node in sortedNodes {
            guard let operation = Operation(rawValue: node.kind) else { continue }
            let ports = inputTypes(for: node, operation: operation)
            if let unknown = node.inputs.keys.sorted().first(where: { ports[$0] == nil }) {
                throw ShaderGraphDiagnostic(code: .unknownInput, nodeID: node.id, port: unknown)
            }
            var inputs: [String: ShaderGraphIR.Input] = [:]
            for port in ports.keys.sorted() {
                guard let expected = ports[port] else { continue }
                guard let link = node.inputs[port] else {
                    if operation == .output { continue }
                    throw ShaderGraphDiagnostic(code: .missingInput, nodeID: node.id, port: port)
                }
                guard let source = lookup[link.node] else {
                    throw ShaderGraphDiagnostic(code: .missingNode, nodeID: node.id, port: port)
                }
                guard let actual = outputType(of: source, port: link.port) else {
                    throw ShaderGraphDiagnostic(code: .unknownPort, nodeID: node.id, port: port)
                }
                let broadcasts = actual == .float && expected.isNumeric
                guard actual == expected || broadcasts else {
                    throw ShaderGraphDiagnostic(code: .typeMismatch, nodeID: node.id, port: port, expected: expected, actual: actual)
                }
                inputs[port] = .init(source: link, type: expected, conversion: actual == expected ? .identity : .scalarBroadcast)
            }
            instructions[node.id] = .init(
                nodeID: node.id,
                operation: operation,
                type: operation == .output ? nil : node.type,
                value: node.value,
                reference: node.reference,
                inputs: inputs
            )
        }

        // Iterative DFS avoids call-stack exhaustion on deep graphs. Visit even unused
        // nodes to diagnose cycles there, but omit them from the resulting program.
        func orderedNodes(startingAt roots: [String]) throws -> [String] {
            var visiting = Set<String>()
            var visited = Set<String>()
            var ordered: [String] = []
            for root in roots {
                var stack = [(root, false)]
                while let (id, exiting) = stack.popLast() {
                    if visited.contains(id) { continue }
                    if exiting {
                        visiting.remove(id)
                        visited.insert(id)
                        ordered.append(id)
                        continue
                    }
                    guard visiting.insert(id).inserted else {
                        throw ShaderGraphDiagnostic(code: .cycle, nodeID: id)
                    }
                    stack.append((id, true))
                    let dependencies = Set(lookup[id]?.inputs.values.map(\.node) ?? []).sorted()
                    stack.append(contentsOf: dependencies.reversed().map { ($0, false) })
                }
            }
            return ordered
        }
        _ = try orderedNodes(startingAt: sortedNodes.map(\.id))
        let reachable = try orderedNodes(startingAt: [output])
        return ShaderGraphIR(target: target, output: output, instructions: reachable.compactMap { instructions[$0] })
    }

    private func validatePayload(_ node: Node, operation: Operation) throws {
        switch operation {
        case .parameter where node.type == .texture2D:
            guard node.value.isEmpty else { throw ShaderGraphDiagnostic(code: .invalidLiteral, nodeID: node.id) }
        case .constant, .parameter:
            guard node.type != .texture2D, node.value.count == node.type.componentCount, node.value.allSatisfy(\.isFinite),
                node.type != .bool || node.value == [0] || node.value == [1] else {
                throw ShaderGraphDiagnostic(code: .invalidLiteral, nodeID: node.id)
            }
        default:
            guard node.value.isEmpty else { throw ShaderGraphDiagnostic(code: .invalidLiteral, nodeID: node.id) }
        }
        if operation == .parameter || operation == .texture {
            guard let reference = node.reference, !reference.isEmpty else {
                throw ShaderGraphDiagnostic(code: .invalidReference, nodeID: node.id)
            }
        } else if node.reference != nil {
            throw ShaderGraphDiagnostic(code: .invalidReference, nodeID: node.id)
        }
        let expected: ValueType?
        switch operation {
        case .texture: expected = .texture2D
        case .sampleTexture: expected = .vector4
        case .uv: expected = .vector2
        case .add, .multiply, .lerp:
            guard node.type.isNumeric else { throw ShaderGraphDiagnostic(code: .typeMismatch, nodeID: node.id, actual: node.type) }
            expected = nil
        default: expected = nil
        }
        if let expected, expected != node.type {
            throw ShaderGraphDiagnostic(code: .typeMismatch, nodeID: node.id, expected: expected, actual: node.type)
        }
    }

    private func inputTypes(for node: Node, operation: Operation) -> [String: ValueType] {
        switch operation {
        case .add, .multiply: ["a": node.type, "b": node.type]
        case .lerp: ["a": node.type, "b": node.type, "t": .float]
        case .sampleTexture: ["texture": .texture2D, "uv": .vector2]
        case .output:
            target == .sprite ? ["color": .color, "alpha": .float] : [
                "baseColor": .color, "normal": .vector3, "metallic": .float, "roughness": .float,
                "emission": .vector3, "occlusion": .float, "alpha": .float
            ]
        default: [:]
        }
    }

    private func outputType(of node: Node, port: String) -> ValueType? {
        guard let operation = Operation(rawValue: node.kind), operation != .output else {
            return nil
        }
        if operation == .sampleTexture {
            return ["value": .vector4, "color": .color, "rgb": .vector3, "alpha": .float][port]
        }
        return port == "value" ? node.type : nil
    }
}
