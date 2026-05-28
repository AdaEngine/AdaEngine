#version 450 core
#pragma stage : vert

#include <AdaEngine/View.glsl>

layout (binding = 3) uniform AE_Mesh2dUniform {
    mat4 u_MeshModel;
    mat4 u_MeshInverseTransposeModel;
};

layout (location = 0) in vec3 a_Position;
layout (location = 2) in vec2 a_UV;

struct VertexOut {
    vec2 UV;
};

layout (location = 0) out VertexOut Output;

[[main]]
void custom_material_vertex()
{
    vec4 worldPosition = u_MeshModel * vec4(a_Position, 1.0);

    Output.UV = a_UV;
    gl_Position = u_ViewProjection * worldPosition;
}
