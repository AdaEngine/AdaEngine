import AdaRender
import Foundation

public enum ShaderGraph3DPipeline {
    public static func make(
        material: ShaderGraphMaterial,
        base: RenderPipeline,
        device: RenderDevice,
        variant: String,
        features: PBRMaterial.ShaderFeatures = [],
        template: String = "Shaders/flat3d.glsl"
    ) throws -> RenderPipeline {
        guard material.program.target == .pbrSurface else {
            throw ShaderGraphDiagnostic(code: .typeMismatch, nodeID: "PBR")
        }
        return try material.pipeline(base: base.descriptor, device: device, variant: variant, defines: features.enablingMacros.map { .define($0) }) {
            guard let url = Bundle.adaModule.resourceURL?.appendingPathComponent(template),
                let fragment = try ShaderSource(from: url).getSource(for: .fragment) else {
                throw ShaderGraphDiagnostic(code: .invalidReference, nodeID: template)
            }
            return fragment
        }
    }
}
