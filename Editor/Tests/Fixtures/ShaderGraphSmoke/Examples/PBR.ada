@system(id: "shader.pbr.smoke", scheduler: "update")
@access(write: [Mesh3DComponent], read: [Transform])
class PBRSmoke {
    @query(Mesh3DComponent, Transform) var meshes;
    func update(context) {
        for (var row in meshes) {
            if (row.transform.position[1] > 0.1) {
                var surface = row.mesh3DComponent.shader(0);
                if (surface.parameterType("roughness") == "float") {
                    surface.setFloat("roughness", 0.85);
                }
            }
        }
    }
}
