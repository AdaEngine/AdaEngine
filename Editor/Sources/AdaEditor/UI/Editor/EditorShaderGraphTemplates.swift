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

    static func initialContent(target: ShaderGraph.Target) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(basic(target: target))).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}
