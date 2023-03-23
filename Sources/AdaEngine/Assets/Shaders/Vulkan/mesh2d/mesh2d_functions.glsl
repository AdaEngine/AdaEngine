
vec4 Mesh2dPositionLocalToWorld(mat4 model, vec4 vertex_position) {
    return model * vertex_position;
}

vec3 Mesh2dNormalLocalToWorld(vec3 vertex_normal) {
    return mat3(
                u_MeshInverseTransposeModel[0].xyz,
                u_MeshInverseTransposeModel[1].xyz,
                u_MeshInverseTransposeModel[2].xyz
                ) * vertex_normal;
}
