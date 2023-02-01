#version 450 core

#ifdef VERTEX
#pragma shader_stage(vertex)

layout(location = 0) in vec4 a_WorldPosition;
layout(location = 1) in vec3 a_LocalPosition;
layout(location = 2) in float a_Thickness;
layout(location = 3) in float a_Fade;
layout(location = 4) in vec4 a_Color;

layout (std140, binding = 1) uniform Camera {
    mat4 u_ViewProjection;
}

layout (push_constant) uniform Transform
{
    mat4 Transform;
} u_Renderer;

struct VertexOutput
{
    vec2 LocalPosition;
    float Fade;
    float Thickness;
    vec4 Color;
};

layout (location = 0) out VertexOutput Output;

void main() {
    Output.LocalPosition = a_LocalPosition;
    Output.Thickness = a_Thickness;
    Output.Color = a_Color;
    Output.Fade = a_Fade;
    gl_Position = u_ViewProjection * u_Renderer.Transform * vec4(worldPosition, 1.0);
}

#else

#pragma shader_stage(fragment)

struct VertexOutput
{
    vec2 LocalPosition;
    float Fade;
    float Thickness;
    vec4 Color;
};

layout (location = 0) in VertexOutput Input;

layout (location = 0) out vec4 FragColor;

void main() {
    float dist = sqrt(dot(Input.LocalPosition, Input.LocalPosition));
    if (dist > 1.0 || dist < 1.0 - Input.Thickness - Input.Fade)
        discard;

    float alpha = 1.0 - smoothstep(1.0f - Input.Fade, 1.0f, dist);
    alpha *= smoothstep(1.0 - Input.Thickness - Input.Fade, 1.0 - Input.Thickness, dist);
    vec4 color = Input.Color;
    color.a = alpha;
    FragColor = color;
}

#endif