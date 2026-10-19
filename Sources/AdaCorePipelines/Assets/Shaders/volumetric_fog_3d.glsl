#version 450 core
#pragma stage : vert
layout (location = 0) out vec2 v_UV;
[[main]]
void volumetric_fog_vertex() {
    vec2 uv = vec2(float(gl_VertexIndex >> 1u), float(gl_VertexIndex & 1u)) * 2.0;
    gl_Position = vec4(uv * vec2(2.0, -2.0) + vec2(-1.0, 1.0), 0.0, 1.0);
    v_UV = uv;
}

#version 450 core
#pragma stage : frag
layout (location = 0) in vec2 v_UV;
layout (location = 0) out vec4 o_Color;
layout (binding = 0) uniform texture2D u_ViewPositionMetallic;
layout (binding = 1) uniform texture2D u_DirectionalShadowTexture;
layout (binding = 2) uniform sampler u_Nearest;
layout (binding = 4) uniform VolumetricFog3DUniform {
    mat4 u_InverseView;
    mat4 u_InverseProjection;
    mat4 u_ShadowViewProjection0;
    mat4 u_ShadowViewProjection1;
    mat4 u_ShadowViewProjection2;
    vec4 u_CascadeSplits; // xyz far view depth of each cascade, w cascade count
    vec4 u_ShadowAtlas;   // xy shadow texel size, z constant bias, w 1 when shadows are enabled
    vec4 u_SunDirection;  // xyz world direction to the sun, w anisotropy
    vec4 u_SunRadiance;   // rgb radiance times intensity times the pass intensity
    vec4 u_Medium;        // x density, y height falloff, z base height, w start distance
    vec4 u_March;         // x steps, y maximum distance, z frame jitter
};

const float PI = 3.14159265359;

float interleavedGradientNoise(vec2 pixel) {
    return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

float henyeyGreenstein(float cosine, float g) {
    float denominator = 1.0 + g * g - 2.0 * g * cosine;
    return (1.0 - g * g) / (4.0 * PI * pow(max(denominator, 0.0001), 1.5));
}

// Whether the sun reaches a world-space point, from the cascade covering its view depth.
float sunVisibility(vec3 world, float viewDepth) {
    if (u_ShadowAtlas.w < 0.5 || viewDepth > u_CascadeSplits.z) { return 1.0; }
    int count = int(u_CascadeSplits.w);
    int cascade = min(viewDepth <= u_CascadeSplits.x ? 0 : (viewDepth <= u_CascadeSplits.y ? 1 : 2), count - 1);
    vec4 position;
    if (cascade == 0) { position = u_ShadowViewProjection0 * vec4(world, 1.0); }
    else if (cascade == 1) { position = u_ShadowViewProjection1 * vec4(world, 1.0); }
    else { position = u_ShadowViewProjection2 * vec4(world, 1.0); }
    vec3 projected = position.xyz / position.w;
    vec2 localUV = projected.xy * vec2(0.5, -0.5) + 0.5;
    if (projected.z < 0.0 || projected.z > 1.0 || any(lessThan(localUV, vec2(0.0))) || any(greaterThan(localUV, vec2(1.0)))) { return 1.0; }
    float cascadeCount = max(u_CascadeSplits.w, 1.0);
    vec2 uv = vec2((localUV.x + float(cascade)) / cascadeCount, localUV.y);
    vec2 minimum = vec2(float(cascade) / cascadeCount, 0.0) + u_ShadowAtlas.xy * 0.5;
    vec2 maximum = vec2(float(cascade + 1) / cascadeCount, 1.0) - u_ShadowAtlas.xy * 0.5;
    float stored = textureLod(sampler2D(u_DirectionalShadowTexture, u_Nearest), clamp(uv, minimum, maximum), 0.0).r;
    return projected.z - u_ShadowAtlas.z <= stored ? 1.0 : 0.0;
}

[[main]]
void volumetric_fog_fragment() {
    vec4 positionMetallic = textureLod(sampler2D(u_ViewPositionMetallic, u_Nearest), v_UV, 0.0);
    vec2 ndc = vec2(v_UV.x * 2.0 - 1.0, 1.0 - v_UV.y * 2.0);
    vec4 viewFar = u_InverseProjection * vec4(ndc, 1.0, 1.0);
    vec3 viewRay = normalize(viewFar.xyz / viewFar.w);
    bool hasSurface = length(positionMetallic.xyz) > 0.0001;
    float surfaceDistance = hasSurface ? length(positionMetallic.xyz) : u_March.y;
    float rangeEnd = min(surfaceDistance, u_March.y);
    float rangeStart = min(u_Medium.w, rangeEnd);
    int steps = int(u_March.x);
    float stepLength = (rangeEnd - rangeStart) / float(steps);
    if (stepLength <= 0.0) {
        o_Color = vec4(0.0);
        return;
    }
    vec3 worldDirection = normalize((u_InverseView * vec4(viewRay, 0.0)).xyz);
    vec3 origin = u_InverseView[3].xyz;
    float phase = henyeyGreenstein(dot(worldDirection, u_SunDirection.xyz), u_SunDirection.w);
    float jitter = fract(interleavedGradientNoise(gl_FragCoord.xy) + u_March.z);

    float transmittance = 1.0;
    float scattered = 0.0;
    for (int index = 0; index < 64; ++index) {
        if (index >= steps) { break; }
        float travel = rangeStart + (float(index) + jitter) * stepLength;
        vec3 world = origin + worldDirection * travel;
        float density = u_Medium.x * exp(clamp(-u_Medium.y * (world.y - u_Medium.z), -60.0, 60.0));
        float step = density * stepLength;
        transmittance *= exp(-step);
        scattered += step * transmittance * sunVisibility(world, travel * viewRay.z);
    }
    o_Color = vec4(u_SunRadiance.rgb * (scattered * phase), 1.0);
}
