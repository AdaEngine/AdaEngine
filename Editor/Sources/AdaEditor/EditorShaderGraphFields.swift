@_spi(AdaEngine) import AdaEngine
import Foundation

enum EditorShaderGraphFields {
    static var path: EditorComponentField {
        var field = EditorComponentField(key: "graphMaterialPath", label: "Shader Graph", kind: .assetReference)
        field.valuePath = ["graphMaterial", "path"]
        field.coding = .shaderGraphPath
        return field
    }

    static func parameters(in payload: EditorComponentPayload) -> [EditorComponentField] {
        guard let value = payload["graphMaterial"], value != .null,
            let data = try? JSONEncoder().encode(value),
            let source = try? JSONDecoder().decode(ShaderGraphMaterialSource.self, from: data) else { return [] }
        let graph: ShaderGraph?
        if let inline = source.graph { graph = inline } else if let path = source.path { graph = try? AssetsManager.loadSync(ShaderGraphAsset.self, at: path).asset.graph } else { graph = nil }
        guard let graph else { return [] }
        var seen = Set<String>()
        return graph.nodes.sorted { ($0.reference ?? "") < ($1.reference ?? "") }.compactMap { node in
            guard node.kind == ShaderGraph.Operation.parameter.rawValue, let id = node.reference, seen.insert(id).inserted else { return nil }
            let kind: EditorComponentFieldKind
            switch node.type {
            case .float: kind = .float
            case .bool: kind = .bool
            case .vector2: kind = .vector2
            case .vector3: kind = .vector3
            case .vector4: kind = .vector4
            case .color: kind = .color
            case .texture2D: kind = .assetReference
            }
            let texture = node.type == .texture2D
            var field = EditorComponentField(key: "\(texture ? "graphTexture" : "graphValue"):\(id)", label: id, kind: kind)
            field.valuePath = ["graphMaterial", texture ? "textures" : "values", id]
            if !texture {
                field.coding = .shaderGraphValue
                field.defaultValue = .array(node.value.map { .double(Double($0)) })
            }
            return field
        }
    }

    static func display(_ field: EditorComponentField, in payload: EditorComponentPayload) -> String {
        guard case let .array(values) = field.storedValue(in: payload) ?? field.defaultValue else { return "" }
        if field.kind == .bool { return values.first?.doubleValue == 1 ? "true" : "false" }
        return values.map(\.stringValue).joined(separator: ", ")
    }

    static func write(_ text: String, field: EditorComponentField, to payload: inout EditorComponentPayload) {
        var root = EditorSceneValue.object(payload)
        if field.coding == .shaderGraphPath {
            let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if path == field.storedValue(in: payload)?.stringValue { return }
            if path.isEmpty { root.setValue(.null, at: field.valuePath.dropLast()[...]) } else {
                let value: EditorSceneValue = .object(["path": .string(path), "values": .object([:]), "textures": .object([:])])
                root.setValue(value, at: field.valuePath.dropLast()[...])
            }
        } else {
            let count = field.kind == .color ? 4 : max(1, field.kind.vectorComponentCount)
            if field.kind == .bool, text != "true", text != "false" { return }
            let parts = text.split { $0 == "," || $0.isWhitespace }
            guard field.kind == .bool || parts.count == count else { return }
            let values = field.kind == .bool ? [text == "true" ? Float(1) : Float(0)] : parts.compactMap { Float($0) }
            guard values.count == count, values.allSatisfy(\.isFinite) else { return }
            root.setValue(.array(values.map { .double(Double($0)) }), at: field.valuePath[...])
        }
        if case let .object(updated) = root { payload = updated }
    }

    static func decode(in payload: EditorComponentPayload, target: ShaderGraph.Target) throws -> ShaderGraphMaterial? {
        guard let value = payload["graphMaterial"], value != .null else { return nil }
        let material = try JSONDecoder().decode(ShaderGraphMaterial.self, from: JSONEncoder().encode(value))
        guard material.program.target == target else { throw ShaderGraphDiagnostic(code: .typeMismatch) }
        return material
    }
}
