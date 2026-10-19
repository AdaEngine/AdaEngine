#version 450 core
#pragma stage : vert
[[main]]
void shadow_clear_vertex() {
    vec2 uv = vec2(float(gl_VertexIndex >> 1u), float(gl_VertexIndex & 1u)) * 2.0;
    gl_Position = vec4(uv * vec2(2.0, -2.0) + vec2(-1.0, 1.0), 0.0, 1.0);
}

#version 450 core
#pragma stage : frag
layout (location = 0) out vec4 o_Color;
[[main]]
void shadow_clear_fragment() {
    o_Color = vec4(1.0);
}
