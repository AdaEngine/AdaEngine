import AdaRender

extension Model3DSource {
    /// Imported textures are shared GPU resources. Material factors, UV settings
    /// and graph parameters belong to this model instance and remain independent.
    static func makeGraphOverride(copying original: Material, source: ShaderGraphMaterialSource) throws -> PBRMaterial {
        guard let original = original as? PBRMaterial else {
            throw ShaderGraphDiagnostic(code: .typeMismatch, nodeID: "PBR")
        }
        let graph = try ShaderGraphMaterial(source: source)
        guard graph.program.target == .pbrSurface else { throw ShaderGraphDiagnostic(code: .typeMismatch, nodeID: "PBR") }
        let material = original.makeInstance()
        material.graphMaterial = graph
        return material
    }
}
