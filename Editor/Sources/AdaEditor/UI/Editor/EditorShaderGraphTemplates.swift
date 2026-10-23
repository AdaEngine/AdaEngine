@_spi(AdaEngine) import AdaEngine
import Foundation

enum EditorShaderGraphTemplates {
    static func basic(target: ShaderGraph.Target) -> ShaderGraph {
        let tint = ShaderGraph.Node(id: "tint", operation: .parameter, type: .color, value: [1, 1, 1, 1], reference: "tint")
        var nodes = [tint]
        var layout: [String: ShaderGraph.Position] = ["tint": .init(x: 30, y: 180), "output": .init(x: 600, y: 100)]
        let color: ShaderGraph.Link
        if target == .sprite {
            nodes.append(.init(id: "sprite", operation: .spriteTexture, type: .color))
            nodes.append(.init(id: "multiply", operation: .multiply, type: .color, inputs: ["a": .init("sprite"), "b": .init("tint")]))
            layout["sprite"] = .init(x: 30, y: 20)
            layout["multiply"] = .init(x: 300, y: 100)
            color = .init("multiply")
        } else {
            color = .init("tint")
        }
        nodes.append(.init(id: "output", operation: .output, inputs: [target == .sprite ? "color" : "baseColor": color]))
        return .init(target: target, output: "output", nodes: nodes, layout: layout)
    }

    static func initialContent(target: ShaderGraph.Target) -> String { encode(basic(target: target)) }

    static func effect(dissolve: Bool) -> ShaderGraph {
        var graph = basic(target: .sprite)
        graph.nodes += [
            .init(id: "uv", operation: .uv, type: .vector2), .init(id: "time", operation: .time),
            .init(id: "speed", operation: .parameter, type: dissolve ? .float : .vector2, value: dissolve ? [0.2] : [0.1, 0], reference: "speed"),
            .init(id: "phase", operation: .multiply, type: dissolve ? .float : .vector2, inputs: ["a": .init("time"), "b": .init("speed")]),
        ]
        if dissolve {
            graph.renderSettings.mode = .mask
            graph.nodes += [
                .init(id: "scale", operation: .parameter, value: [8], reference: "scale"),
                .init(id: "scaledUV", operation: .multiply, type: .vector2, inputs: ["a": .init("uv"), "b": .init("scale")]),
                .init(id: "noise", operation: .noise2D, inputs: ["uv": .init("scaledUV")]), .init(id: "progress", operation: .fraction, inputs: ["value": .init("phase")]),
                .init(id: "alpha", operation: .step, inputs: ["edge": .init("progress"), "value": .init("noise")]),
            ]
            if let index = graph.nodes.firstIndex(where: { $0.id == graph.output }) { graph.nodes[index].inputs["alpha"] = .init("alpha") }
        } else {
            graph.nodes += [
                .init(id: "shiftedUV", operation: .add, type: .vector2, inputs: ["a": .init("uv"), "b": .init("phase")]),
                .init(id: "wrappedUV", operation: .fraction, type: .vector2, inputs: ["value": .init("shiftedUV")]),
            ]
            if let index = graph.nodes.firstIndex(where: { $0.id == "sprite" }) { graph.nodes[index].inputs["uv"] = .init("wrappedUV") }
        }
        for (index, node) in graph.nodes.enumerated() { graph.layout[node.id] = .init(x: Float(index % 4) * 270 + 30, y: Float(index / 4) * 220 + 30) }
        return graph
    }

    static func encode(_ graph: ShaderGraph) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(graph)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}
