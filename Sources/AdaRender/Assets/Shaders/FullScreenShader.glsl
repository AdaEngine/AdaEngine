#version 450 core
#pragma stage : vert

layout (location = 0) out vec2 v_UV;

void main() {
    uint vertex_index = gl_VertexIndex;
    vec2 uv = vec2(float(vertex_index >> 1u), float(vertex_index & 1u)) * 2.0;
    gl_Position = vec4(uv * vec2(2.0, -2.0) + vec2(-1.0, 1.0), 0.0, 1.0);
    v_UV = uv;
}

#version 450 core
#pragma stage : frag

layout (location = 0) in vec2 v_UV;
layout (location = 0) out vec4 o_Color;

layout (binding = 0) uniform sampler2D u_MainTexture;

void main() {
    o_Color = texture(u_MainTexture, v_UV);
}
