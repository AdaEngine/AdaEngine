@_spi(AdaEngine) import AdaEngine
import Observation

struct EditorShaderGraphNodeEntry: Identifiable {
    let operation: ShaderGraph.Operation
    let type: ShaderGraph.ValueType
    var id: String { operation.rawValue + ":" + type.rawValue }

    @MainActor var title: String { L10n.tr(EditorShaderGraphModel.operationTitle(operation.rawValue)) + " · " + type.rawValue }
    var node: ShaderGraph.Node { .init(id: "candidate", operation: operation, type: type) }
}

@Observable @MainActor final class EditorShaderGraphSearch {
    var isPresented = false
    var query = ""
    var point = Vector2(100, 100)
    var endpoint: EditorNodeCanvasEndpoint?
    var replacedInput: EditorNodeCanvasEndpoint?

    func open(at point: Vector2, endpoint: EditorNodeCanvasEndpoint? = nil) {
        self.point = point
        self.endpoint = endpoint
        replacedInput = nil
        query = ""
        isPresented = true
    }

    func entries(in graph: ShaderGraph) -> [EditorShaderGraphNodeEntry] {
        let numeric: [ShaderGraph.ValueType] = [.float, .vector2, .vector3, .vector4, .color]
        let all = ShaderGraph.Operation.allCases.filter { $0 != .output && ($0 != .spriteTexture || graph.target == .sprite) }.flatMap { operation in
            let types: [ShaderGraph.ValueType]
            switch operation {
            case .constant: types = numeric + [.bool]
            case .parameter: types = numeric + [.bool, .texture2D]
            case .texture: types = [.texture2D]
            case .sampleTexture, .combine4: types = [.vector4]
            case .uv, .combine2: types = [.vector2]
            case .combine3: types = [.vector3]
            case .time, .noise2D: types = [.float]
            case .spriteTexture: types = [.color]
            default: types = numeric
            }
            return types.map { EditorShaderGraphNodeEntry(operation: operation, type: $0) }
        }
        return all.filter { entry in
            let matches = query.lowercased().split(whereSeparator: \.isWhitespace).allSatisfy { (entry.title + " " + entry.id).lowercased().contains($0) }
            guard matches, let endpoint else {
                return matches
            }
            guard let existing = graph.nodes.first(where: { $0.id == endpoint.node }) else {
                return false
            }
            if endpoint.isOutput, let type = graph.outputPorts(for: existing)[endpoint.port] {
                return graph.inputPorts(for: entry.node).values.contains { Self.compatible(type, with: $0) }
            }
            if let type = graph.inputPorts(for: existing)[endpoint.port] {
                return graph.outputPorts(for: entry.node).values.contains { Self.compatible($0, with: type) }
            }
            return false
        }
    }

    static func compatible(_ source: ShaderGraph.ValueType, with target: ShaderGraph.ValueType) -> Bool { source == target || source == .float && target != .bool && target != .texture2D }
}
