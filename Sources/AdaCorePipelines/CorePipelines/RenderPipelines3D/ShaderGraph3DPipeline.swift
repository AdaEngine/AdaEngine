import AdaRender
import Foundation

public enum ShaderGraph3DPipeline {
    /// Shared silhouette rules for directional/local shadow maps and visibility depth.
    public static func bindShadow(
        encoder: RenderCommandEncoder,
        base: RenderPipeline,
        material: Material,
        device: RenderDevice,
        morph: Bool
    ) -> Bool {
        guard let pbr = material as? PBRMaterial, pbr.effectiveAlphaMode == .mask, let graph = pbr.graphMaterial else {
            encoder.setRenderPipelineState(base)
            return true
        }
        do {
            let formats = base.descriptor.colorAttachments.map { String(describing: $0.format) }.joined(separator: ",")
            let pipeline = try make(
                material: graph, base: base, device: device,
                variant: "shadow:\(formats):\(base.descriptor.depthPixelFormat):\(morph)",
                features: morph ? .morph : [], template: "Shaders/directional_shadow_3d.glsl"
            )
            encoder.setRenderPipelineState(pipeline)
            graph.bind(to: encoder, device: device)
            return true
        } catch {
            graph.reportCompilationError(error)
            return false
        }
    }

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
