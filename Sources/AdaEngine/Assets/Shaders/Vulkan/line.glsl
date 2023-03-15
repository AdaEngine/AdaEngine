#version 450 core
#pragma stage : vert

layout(location = 0) in vec3 a_Position;
layout(location = 1) in vec4 a_Color;
layout(location = 2) in float a_LineWidth;

layout (std140, binding = 1) uniform Camera {
    mat4 u_ViewProjection;
};

struct VertexOut {
    vec4 Color;
};

layout (location = 0) out VertexOutput Output;

void main() {
    Output.Color = a_Color;
    gl_Position = u_ViewProjection * vec4(a_Position, 1.0);
}

#version 450 core
#pragma stage : frag

layout(location = 0) out vec4 color;

struct VertexOut {
    vec4 Color;
};

layout (location = 0) out VertexOutput Input;

void main() {
    color = Input.Color;
}
