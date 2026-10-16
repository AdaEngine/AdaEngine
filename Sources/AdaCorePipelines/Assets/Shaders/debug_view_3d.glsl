#version 450 core
#pragma stage : vert
layout (location = 0) out vec2 v_UV;
[[main]]
void debug_view_vertex() {
    vec2 uv = vec2(float(gl_VertexIndex >> 1u), float(gl_VertexIndex & 1u)) * 2.0;
    gl_Position = vec4(uv * vec2(2.0, -2.0) + vec2(-1.0, 1.0), 0.0, 1.0);
    v_UV = uv;
}
#version 450 core
#pragma stage : frag
layout (location = 0) in vec2 v_UV;
layout (location = 0) out vec4 o_Color;
layout (binding = 0) uniform texture2D u_NormalRoughness;
layout (binding = 1) uniform texture2D u_PositionMetallic;
layout (binding = 2) uniform texture2D u_AmbientOcclusion;
layout (binding = 3) uniform texture2D u_Indirect;
layout (binding = 4) uniform sampler u_Nearest;
layout (binding = 6) uniform texture2D u_SceneColor;
layout (binding = 5) uniform DebugView3DUniform {
    vec4 u_Parameters; // x mode (0 normals ... 7 scene color), y depth scale
};
[[main]]
void debug_view_fragment() {
    vec4 normalRoughness = texture(sampler2D(u_NormalRoughness, u_Nearest), v_UV);
    vec4 positionMetallic = texture(sampler2D(u_PositionMetallic, u_Nearest), v_UV);
    // The main pass clears both targets to black, so a zero normal marks pixels without geometry.
    bool covered = length(normalRoughness.xyz) > 0.1;
    float mode = u_Parameters.x;
    vec3 color = vec3(0.04);
    if (mode < 1.5) {
        if (covered) { color = normalize(normalRoughness.xyz) * 0.5 + 0.5; }
    } else if (mode < 2.5) {
        if (covered) { color = vec3(1.0 - exp(-positionMetallic.z * u_Parameters.y)); }
    } else if (mode < 3.5) {
        if (covered) { color = vec3(normalRoughness.w); }
    } else if (mode < 4.5) {
        if (covered) { color = vec3(positionMetallic.w); }
    } else if (mode < 5.5) {
        color = vec3(texture(sampler2D(u_AmbientOcclusion, u_Nearest), v_UV).r);
    } else if (mode < 6.5) {
        if (covered) { color = vec3(1.0) - exp(-texture(sampler2D(u_Indirect, u_Nearest), v_UV).rgb * 24.0); }
    } else {
        // Albedo, cascades and light count: the main pass already wrote display-ready colors into scene color.
        if (covered) { color = clamp(texture(sampler2D(u_SceneColor, u_Nearest), v_UV).rgb, 0.0, 1.0); }
    }
    o_Color = vec4(color, 1.0);
}
