@_spi(AdaEngine) import AdaEngine
import Foundation

extension EditorShaderGraphModel {
    var canvasItems: [EditorNodeCanvasItem] {
        guard let graph else {
            return []
        }
        return graph.nodes.enumerated().map { index, node in
            let position = graph.layout[node.id] ?? .init(x: Float(index % 4) * 260, y: Float(index / 4) * 240)
            @MainActor func ports(_ values: [String: ShaderGraph.ValueType]) -> [EditorNodeCanvasPort] {
                values.keys.sorted().compactMap { id in values[id].map { .init(id: id, title: L10n.tr(Self.portTitle(id)), type: $0.rawValue) } }
            }
            return .init(
                id: node.id,
                title: node.label ?? L10n.tr(Self.operationTitle(node.kind)),
                position: [position.x, position.y],
                inputs: ports(graph.inputPorts(for: node)),
                outputs: ports(graph.outputPorts(for: node)),
                subtitle: node.reference,
                hasError: validation?.nodeID == node.id
            )
        }
    }

    var canvasWires: [EditorNodeCanvasWire] {
        guard let graph else {
            return []
        }
        return graph.nodes.flatMap { node in
            node.inputs.sorted { $0.key < $1.key }.map { port, link in
                let type = graph.nodes.first { $0.id == link.node }.flatMap { graph.outputPorts(for: $0)[link.port] }
                return .init(source: .init(node: link.node, port: link.port, isOutput: true), target: .init(node: node.id, port: port, isOutput: false), type: type?.rawValue ?? "float")
            }
        }
    }

    func canvasInteraction() -> EditorNodeCanvasInteraction {
        let interaction = EditorNodeCanvasInteraction()
        interaction.select = { [weak self] in self?.selection = $0 }
        interaction.begin = { [weak self] in self?.beginTransaction() }
        interaction.commit = { [weak self] in self?.endTransaction() }
        interaction.cancel = { [weak self] in self?.cancelTransaction() }
        interaction.move = { [weak self] positions in self?.edit(semantic: false) { graph in for (id, value) in positions { graph.layout[id] = .init(x: value.x, y: value.y) } } }
        interaction.connect = { [weak self] source, target in self?.connect(.init(source.node, port: source.port), to: target.node, port: target.port) }
        return interaction
    }

    func addNode(_ operation: ShaderGraph.Operation, type: ShaderGraph.ValueType, at position: Vector2) {
        guard let graph, operation != .output, operation != .spriteTexture || graph.target == .sprite else {
            return
        }
        let id = UUID().uuidString
        var node = ShaderGraph.Node(id: id, operation: operation, type: type)
        switch operation {
        case .constant, .parameter:
            node.value = Self.defaultValue(type)
            if operation == .parameter { node.reference = id }
        case .texture: node.reference = "texture.png"
        default: break
        }
        if edit({ graph in
            graph.nodes.append(node)
            graph.layout[id] = .init(x: position.x, y: position.y)
        }) {
            selection = [id]
        }
    }

    static func defaultValue(_ type: ShaderGraph.ValueType) -> [Float] {
        switch type {
        case .color: [1, 1, 1, 1]
        case .vector2: [0, 0]
        case .vector3: [0, 0, 0]
        case .vector4: [0, 0, 0, 0]
        case .float, .bool: [0]
        case .texture2D: []
        }
    }

    static func operationTitle(_ kind: String) -> String {
        switch ShaderGraph.Operation(rawValue: kind) {
        case .constant: "Constant"
        case .parameter: "Parameter"
        case .texture: "Texture"
        case .sampleTexture: "Sample Texture"
        case .uv: "UV"
        case .spriteTexture: "Sprite Texture"
        case .add: "Add"
        case .multiply: "Multiply"
        case .lerp: "Lerp"
        case .output: "Output"
        case nil: kind
        }
    }

    static func portTitle(_ id: String) -> String {
        switch id {
        case "value": "Value"
        case "color", "baseColor": "Color"
        case "alpha": "Alpha"
        case "normal": "Normal"
        case "metallic": "Metallic"
        case "roughness": "Roughness"
        case "emission": "Emission"
        case "occlusion": "Occlusion"
        case "texture": "Texture"
        default: id
        }
    }
}
