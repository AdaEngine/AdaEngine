#version 450 core
#pragma stage : vert

#include <AdaEngine/View.glsl>

layout (location = 0) in vec3 a_Position;
layout (location = 1) in vec3 a_Normal;

layout (binding = 3) uniform AE_Model {
    mat4 u_Model;
    vec4 u_Color;
};

struct VertexOut
{
    vec4 Color;
};

layout (location = 0) out VertexOut Output;

[[main]]
void flat3d_vertex()
{
    vec3 normal = normalize(mat3(u_Model) * a_Normal);
    float light = max(dot(normal, normalize(vec3(0.35, 0.7, 0.45))), 0.0);
    Output.Color = vec4(u_Color.rgb * (0.35 + light * 0.65), u_Color.a);
    gl_Position = u_ViewProjection * u_Model * vec4(a_Position, 1.0);
}

#version 450 core
#pragma stage : frag

layout (location = 0) out vec4 color;

struct VertexOut
{
    vec4 Color;
};

layout (location = 0) in VertexOut Input;

[[main]]
void flat3d_fragment()
{
    color = Input.Color;
}
