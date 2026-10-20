/// Generated fragment functions and their renderer-independent binding contract.
public struct ShaderGraphProgram: Hashable, Sendable {
    public static let uniformBinding = 28
    // Group 1 avoids the vertex View (2) and Skinning (14) bindings in group 0;
    // slot 14 also fits Metal's sixteen sampler slots without replacing stock samplers.
    public static let samplerBinding = 14
    public static let samplerSet = 1
    public static let firstTextureBinding = 48

    public struct Parameter: Hashable, Sendable {
        public let id: String
        public let type: ShaderGraph.ValueType
        public let defaultValue: [Float]
        /// One aligned vec4 per parameter; slot zero contains animation time.
        public let slot: Int
    }

    public struct Texture: Hashable, Sendable {
        public let parameterID: String?
        public let path: String?
        public let binding: Int
    }

    public struct Location: Hashable, Sendable {
        public let nodeID: String
        public let port: String?
    }

    public let target: ShaderGraph.Target
    /// Cache shaders by this source, not parameter defaults, resource paths or layout.
    public let source: String
    public let parameters: [Parameter]
    public let textures: [Texture]
    public let sourceMap: [Int: Location]
}

extension ShaderGraph.ValueType {
    var glslType: String {
        switch self {
        case .float: "float"
        case .bool: "bool"
        case .vector2: "vec2"
        case .vector3: "vec3"
        case .vector4, .color: "vec4"
        case .texture2D: "texture2D"
        }
    }
}

extension ShaderGraph {
    /// Generates GLSL without touching a GPU. User identifiers are never interpolated as shader code.
    public func compileGLSL() throws -> ShaderGraphProgram {
        let ir = try lowered()
        let numeric = ir.instructions.filter { $0.operation == .parameter && $0.type != .texture2D }
        let ids = Set(numeric.compactMap(\.reference)).sorted()
        let parameters: [ShaderGraphProgram.Parameter] = ids.enumerated().compactMap { index, id in
            guard let node = numeric.first(where: { $0.reference == id }), let type = node.type else {
                return nil
            }
            return .init(id: id, type: type, defaultValue: node.value, slot: index + 1)
        }
        var textures: [ShaderGraphProgram.Texture] = []
        var textureNames: [String: String] = [:]
        for node in ir.instructions where node.type == .texture2D {
            let parameter = node.operation == .parameter ? node.reference : nil
            let path = node.operation == .texture ? node.reference : nil
            let index: Int
            if let existing = textures.firstIndex(where: { $0.parameterID == parameter && $0.path == path }) {
                index = existing
            } else {
                index = textures.count
                textures.append(.init(parameterID: parameter, path: path, binding: ShaderGraphProgram.firstTextureBinding + index))
            }
            textureNames[node.nodeID] = "ada_graph_texture\(index)"
        }
        var lines = [
            "layout(binding = \(ShaderGraphProgram.uniformBinding)) uniform AdaGraphUniforms { vec4 ada_graph_values[\(parameters.count + 1)]; };"
        ]
        if !textures.isEmpty {
            lines.append("layout(set = \(ShaderGraphProgram.samplerSet), binding = \(ShaderGraphProgram.samplerBinding)) uniform sampler ada_graph_sampler;")
        }
        for (index, texture) in textures.enumerated() {
            lines.append("layout(binding = \(texture.binding)) uniform texture2D ada_graph_texture\(index);")
        }
        lines += [
            "struct AdaGraphSurface { vec4 color; vec3 normal; float metallic; float roughness; vec3 emission; float occlusion; float alpha; };",
            "AdaGraphSurface ada_graph_evaluate(vec2 ada_graph_uv) {",
            "AdaGraphSurface surface; surface.color = vec4(1.0); surface.normal = vec3(0.0, 0.0, 1.0);",
            "surface.metallic = 0.0; surface.roughness = 0.5; surface.emission = vec3(0.0); surface.occlusion = 1.0; surface.alpha = 1.0;"
        ]
        let names = Dictionary(uniqueKeysWithValues: ir.instructions.enumerated().map { ($1.nodeID, "ada_graph_n\($0)") })
        var locations: [Int: ShaderGraphProgram.Location] = [:]
        func input(_ link: ShaderGraphIR.Input) -> String {
            let base = textureNames[link.source.node] ?? names[link.source.node] ?? "0.0"
            let suffix = link.source.port == "rgb" ? ".rgb" : link.source.port == "alpha" ? ".a" : ""
            let value = base + suffix
            return link.conversion == .scalarBroadcast ? "\(link.type.glslType)(\(value))" : value
        }
        for node in ir.instructions {
            let name = names[node.nodeID] ?? "ada_graph_unused"
            func argument(_ port: String) -> String { node.inputs[port].map(input) ?? "0.0" }
            if node.operation == .output {
                for port in node.inputs.keys.sorted() {
                    locations[lines.count + 1] = .init(nodeID: node.nodeID, port: port)
                    lines.append("surface.\(port == "baseColor" ? "color" : port) = \(argument(port));")
                }
                continue
            }
            guard let type = node.type, type != .texture2D else { continue }
            let expression: String
            switch node.operation {
            case .constant:
                expression = type == .bool ? (node.value == [1] ? "true" : "false")
                    : "\(type.glslType)(\(node.value.map(String.init(describing:)).joined(separator: ", ")))"
            case .parameter:
                let slot = parameters.first { $0.id == node.reference }?.slot ?? 0
                let value = "ada_graph_values[\(slot)]"
                switch type {
                case .bool: expression = "(\(value).x != 0.0)"
                case .float: expression = value + ".x"
                case .vector2: expression = value + ".xy"
                case .vector3: expression = value + ".xyz"
                default: expression = value
                }
            case .uv: expression = "ada_graph_uv"
            case .spriteTexture: expression = "texture(sampler2D(u_Texture, u_Sampler), ada_graph_uv)"
            case .add: expression = "(\(argument("a")) + \(argument("b")))"
            case .multiply: expression = "(\(argument("a")) * \(argument("b")))"
            case .lerp: expression = "mix(\(argument("a")), \(argument("b")), \(argument("t")))"
            case .sampleTexture: expression = "texture(sampler2D(\(argument("texture")), ada_graph_sampler), \(argument("uv")))"
            case .texture, .output: continue
            }
            locations[lines.count + 1] = .init(nodeID: node.nodeID, port: nil)
            lines.append("\(type.glslType) \(name) = \(expression);")
        }
        lines += ["return surface;", "}"]
        return ShaderGraphProgram(target: target, source: lines.joined(separator: "\n"), parameters: parameters, textures: textures, sourceMap: locations)
    }
}
