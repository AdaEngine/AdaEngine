@testable import AdaRender
import Foundation
import Testing

@Suite("Generated shader graph functions", .serialized)
struct ShaderGraphProgramTests {
    private func graph() -> ShaderGraph {
        ShaderGraph(target: .sprite, output: "output", nodes: [
            .init(id: "uv", operation: .uv, type: .vector2),
            .init(id: "texture", operation: .texture, type: .texture2D, reference: "stone.png"),
            .init(id: "sample", operation: .sampleTexture, type: .vector4, inputs: ["texture": .init("texture"), "uv": .init("uv")]),
            .init(id: "tint", operation: .parameter, type: .color, value: [1, 1, 1, 1], reference: "tint; invalid shader identifier"),
            .init(id: "multiply", operation: .multiply, type: .color, inputs: ["a": .init("sample", port: "color"), "b": .init("tint")]),
            .init(id: "output", operation: .output, inputs: ["color": .init("multiply")])
        ])
    }

    @Test func resourcesAndDefaultsDoNotChangeCompiledCode() throws {
        var graph = graph()
        let before = try graph.compileGLSL()
        graph.nodes[1].reference = "other.png"
        graph.nodes[3].value = [0, 0, 0, 1]
        graph.nodes.reverse()
        let after = try graph.compileGLSL()
        #expect(before.source == after.source)
        #expect(before.parameters != after.parameters)
        #expect(before.textures != after.textures)
        #expect(!after.source.contains("invalid shader identifier"))
        #expect(after.parameters[0].slot == 1)
        #expect(after.textures[0].binding == ShaderGraphProgram.firstTextureBinding)
        #expect(!after.sourceMap.isEmpty)
    }

    @Test(arguments: [ShaderGraph.Target.sprite, .pbrSurface])
    func realCompilerAcceptsGeneratedFunctions(target: ShaderGraph.Target) throws {
        var graph = graph()
        graph.target = target
        if target == .pbrSurface { graph.nodes[5].inputs = ["baseColor": .init("multiply"), "emission": .init("sample", port: "rgb")] }
        let program = try graph.compileGLSL()
        let source = try ShaderSource(source: """
        #version 450 core
        #pragma stage : frag
        layout(location = 0) out vec4 result;
        \(program.source)
        void main() { AdaGraphSurface s = ada_graph_evaluate(vec2(0.5)); result = s.color + vec4(s.emission, 0.0); }
        """)
        let binary = try ShaderCompiler(shaderSource: source).compileSpirvBin(for: .fragment, ignoreCache: true)
        #expect(!binary.data.isEmpty)
        let reflection = try SpirvCompiler(spriv: binary.data, stage: .fragment, deviceLang: .glsl).reflection()
        #expect(reflection.descriptorSets[0].uniformsBuffers[ShaderGraphProgram.uniformBinding] != nil)
        #expect(reflection.descriptorSets[0].sampledImages[ShaderGraphProgram.firstTextureBinding] != nil)
        #expect(reflection.descriptorSets[ShaderGraphProgram.samplerSet].samplers[ShaderGraphProgram.samplerBinding] != nil)
    }
}
