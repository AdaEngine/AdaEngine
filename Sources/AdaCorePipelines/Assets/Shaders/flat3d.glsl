#version 450 core
#pragma stage : vert

#include <AdaEngine/View.glsl>

layout (location = 0) in vec3 a_Position;
layout (location = 1) in vec3 a_Normal;
layout (location = 2) in vec4 a_Model0;
layout (location = 3) in vec4 a_Model1;
layout (location = 4) in vec4 a_Model2;
layout (location = 5) in vec4 a_Model3;
layout (location = 6) in vec4 a_Color;
layout (location = 7) in vec4 a_Material;

struct VertexOut
{
    vec4 Color;
    vec3 ViewPosition;
    vec3 ViewNormal;
    float Roughness;
    float Metallic;
};

layout (location = 0) out VertexOut Output;

[[main]]
void flat3d_vertex()
{
    mat4 model = mat4(a_Model0, a_Model1, a_Model2, a_Model3);
    vec3 normal = normalize(mat3(model) * a_Normal);
    vec4 worldPosition = model * vec4(a_Position, 1.0);
    float light = max(dot(normal, normalize(vec3(0.35, 0.7, 0.45))), 0.0);
    Output.Color = vec4(a_Color.rgb * (0.35 + light * 0.65), a_Color.a);
    Output.ViewPosition = (u_ViewMatrix * worldPosition).xyz;
    Output.ViewNormal = normalize(mat3(u_ViewMatrix) * normal);
    Output.Roughness = clamp(a_Material.x, 0.04, 1.0);
    Output.Metallic = clamp(a_Material.y, 0.0, 1.0);
    gl_Position = u_ViewProjection * worldPosition;
}

#version 450 core
#pragma stage : frag

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 normalRoughness;
layout (location = 2) out vec4 viewPositionMetallic;

struct VertexOut
{
    vec4 Color;
    vec3 ViewPosition;
    vec3 ViewNormal;
    float Roughness;
    float Metallic;
};

layout (location = 0) in VertexOut Input;

[[main]]
void flat3d_fragment()
{
    color = Input.Color;
    normalRoughness = vec4(normalize(Input.ViewNormal), Input.Roughness);
    viewPositionMetallic = vec4(Input.ViewPosition, Input.Metallic);
}
