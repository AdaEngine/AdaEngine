import AdaRender
import Foundation

enum SpriteGraphPipeline {
    static func make(material: ShaderGraphMaterial, base: RenderPipeline, instanced: Bool, device: RenderDevice) throws -> RenderPipeline {
        guard material.program.target == .sprite else {
            throw ShaderGraphDiagnostic(code: .typeMismatch, nodeID: "Sprite")
        }
        return try material.pipeline(base: base.descriptor, device: device, variant: instanced ? "sprite-instanced" : "sprite-expanded") {
            let path = instanced ? "Assets/sprite_instanced.glsl" : "Assets/sprite.glsl"
            guard let url = Bundle.adaModule.resourceURL?.appendingPathComponent(path),
                let fragment = try ShaderSource(from: url).getSource(for: .fragment) else {
                throw ShaderGraphDiagnostic(code: .invalidReference, nodeID: path)
            }
            return fragment
        }
    }
}
