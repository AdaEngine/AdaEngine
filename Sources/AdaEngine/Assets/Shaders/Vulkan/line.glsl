#version 410 core
#pragma stage : vert

#include <AdaEngine/View.glsl>

layout (location = 0) in vec3 a_Position;
layout (location = 1) in vec4 a_Color;
layout (location = 2) in float a_LineWidth;

struct VertexOutput {
    vec4 Color;
};

layout (location = 0) out VertexOutput Output;

[[main]]
void line_vertex() {
    Output.Color = a_Color;
    gl_Position = u_ViewProjection * vec4(a_Position, 1.0);
}

#version 410 core
#pragma stage : frag

layout (location = 0) out vec4 color;

struct VertexOutput {
    vec4 Color;
};

layout (location = 0) in VertexOutput Input;

[[main]]
void line_fragment() {
    color = Input.Color;
}
