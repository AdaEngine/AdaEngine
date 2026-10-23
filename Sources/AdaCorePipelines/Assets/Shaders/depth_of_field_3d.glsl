#version 450 core
#pragma stage : vert
layout (location = 0) out vec2 v_UV;
[[main]]
void depth_of_field_vertex() {
    vec2 uv = vec2(float(gl_VertexIndex >> 1u), float(gl_VertexIndex & 1u)) * 2.0;
    gl_Position = vec4(uv * vec2(2.0, -2.0) + vec2(-1.0, 1.0), 0.0, 1.0);
    v_UV = uv;
}
#version 450 core
#pragma stage : frag
layout (location = 0) in vec2 v_UV;
layout (location = 0) out vec4 o_Color;
layout (binding = 0) uniform texture2D u_Color;
layout (binding = 1) uniform texture2D u_PositionMetallic;
layout (binding = 2) uniform sampler u_Linear;
layout (binding = 3) uniform sampler u_Nearest;
layout (binding = 4) uniform DepthOfField3DUniform {
    vec4 u_Parameters; // x mode (0 gather, 1 copy), y focus distance, z aperture, w maximum blur radius in pixels
    vec4 u_Size;       // xy one over the color size in pixels
};

const int SAMPLE_COUNT = 24;
const float GOLDEN_ANGLE = 2.39996323;

// Blur radius in pixels for a view-space depth. Pixels without geometry count as infinitely far.
float circleOfConfusion(vec2 uv) {
    vec4 position = textureLod(sampler2D(u_PositionMetallic, u_Nearest), uv, 0.0);
    float depth = length(position.xyz) < 0.0001 ? 100000.0 : max(position.z, 0.001);
    return clamp(u_Parameters.z * abs(depth - u_Parameters.y) / depth * u_Parameters.w, 0.0, u_Parameters.w);
}

vec3 colorAt(vec2 uv) {
    return textureLod(sampler2D(u_Color, u_Linear), uv, 0.0).rgb;
}

// Gathers a Vogel disc as wide as this pixel's blur radius. A neighbor contributes only as much as its own blur
// radius reaches this pixel, so sharp surfaces never smear into a blurred neighbor and in-focus pixels keep
// their detail.
vec4 gather() {
    vec3 center = colorAt(v_UV);
    float radius = circleOfConfusion(v_UV);
    if (radius < 0.5) {
        return vec4(center, 1.0);
    }
    vec3 sum = center;
    float weightSum = 1.0;
    for (int index = 0; index < SAMPLE_COUNT; ++index) {
        float distanceInPixels = sqrt((float(index) + 0.5) / float(SAMPLE_COUNT)) * radius;
        float angle = float(index) * GOLDEN_ANGLE;
        vec2 uv = v_UV + vec2(cos(angle), sin(angle)) * distanceInPixels * u_Size.xy;
        float weight = clamp(circleOfConfusion(uv) / max(distanceInPixels, 1.0), 0.0, 1.0);
        sum += colorAt(uv) * weight;
        weightSum += weight;
    }
    return vec4(sum / weightSum, 1.0);
}

[[main]]
void depth_of_field_fragment() {
    if (u_Parameters.x < 0.5) {
        o_Color = gather();
    } else {
        o_Color = vec4(textureLod(sampler2D(u_Color, u_Nearest), v_UV, 0.0).rgb, 1.0);
    }
}
