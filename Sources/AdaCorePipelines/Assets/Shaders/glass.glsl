#version 450 core
#pragma stage : vert

#include <AdaEngine/View.glsl>

layout (location = 0) in vec4 a_Position;
layout (location = 1) in vec4 a_Color;
layout (location = 2) in vec2 a_TexCoordinate;
layout (location = 3) in vec4 a_GlassParams;   // x=blurRadius, y=cornerRadius, z=tintStrength, w=edgeShadow
layout (location = 4) in vec4 a_GlassInfo;     // x=halfWidth, y=halfHeight, z=scaleFactor, w=overallShadow

layout (location = 0) out vec4 v_Color;
layout (location = 1) out vec2 v_TexCoordinate;
layout (location = 2) out vec4 v_GlassParams;
layout (location = 3) out vec4 v_GlassInfo;

[[main]]
void glass_vertex() {
    v_Color = a_Color;
    v_TexCoordinate = a_TexCoordinate;
    v_GlassParams = a_GlassParams;
    v_GlassInfo = a_GlassInfo;
    gl_Position = u_ViewProjection * a_Position;
}

#version 450 core
#pragma stage : frag

layout (location = 0) out vec4 o_Color;

layout (location = 0) in vec4 v_Color;
layout (location = 1) in vec2 v_TexCoordinate;
layout (location = 2) in vec4 v_GlassParams;  // blurRadius, cornerRadius, tintStrength, edgeShadow
layout (location = 3) in vec4 v_GlassInfo;    // halfWidth, halfHeight, scaleFactor, opacity

layout (binding = 0) uniform texture2D u_BackgroundTexture;
layout (binding = 1) uniform sampler u_BackgroundSampler;

const float kGoldenAngle = 2.39996323;
const int kBlurSamples = 32;

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

vec3 sampleBlurred(vec2 uv, vec2 texelSize, float radius) {
    if (radius < 0.5) {
        return texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), uv).rgb;
    }
    vec3 value = texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), uv).rgb;
    float totalWeight = 1.0;
    for (int i = 1; i < kBlurSamples; i++) {
        float t = float(i) / float(kBlurSamples - 1);
        float r = sqrt(t) * radius;
        float theta = float(i) * kGoldenAngle;
        vec2 offset = vec2(cos(theta), sin(theta)) * r * texelSize;
        vec2 sampleUV = clamp(uv + offset, vec2(0.001), vec2(0.999));
        float weight = 1.0 - t * 0.7;
        value += texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), sampleUV).rgb * weight;
        totalWeight += weight;
    }
    return value / totalWeight;
}

[[main]]
void glass_fragment() {
    float blurRadius   = v_GlassParams.x;
    float cornerRadius = v_GlassParams.y;
    float tintStrength = v_GlassParams.z;
    float edgeShadow   = v_GlassParams.w;
    float halfW        = v_GlassInfo.x;
    float halfH        = v_GlassInfo.y;
    float scaleFactor  = v_GlassInfo.z;
    float glassOpacity = v_GlassInfo.w;

    // Background UV derived from physical screen coordinates
    ivec2 bgTexSizeI = textureSize(sampler2D(u_BackgroundTexture, u_BackgroundSampler), 0);
    vec2 bgTexSize = vec2(bgTexSizeI);
    vec2 bgUV = gl_FragCoord.xy / bgTexSize;
    vec2 texelSize = 1.0 / bgTexSize;

    // Blur radius in physical pixels
    float blurPhysical = blurRadius * scaleFactor;

    // Local position in logical pixels relative to quad center
    vec2 localPos = (v_TexCoordinate - 0.5) * 2.0 * vec2(halfW, halfH);

    // SDF for corner clipping and edge effects
    float sdf = sdRoundedBox(localPos, vec2(halfW, halfH), cornerRadius);
    float edgeAA = length(vec2(dFdx(sdf), dFdy(sdf)));
    edgeAA = max(edgeAA, 0.5);

    if (sdf > edgeAA * 2.0) {
        discard;
    }

    float distFromEdge = -sdf;
    float aa = clamp(0.5 - sdf / (edgeAA * 2.0), 0.0, 1.0);

    // Sample blurred background
    vec3 color = sampleBlurred(bgUV, texelSize, blurPhysical);
    float lum = dot(color, vec3(0.299, 0.587, 0.114));

    // Frosted glass tinting — adaptive to background luminance.
    float regime = smoothstep(0.35, 0.65, lum);

    vec3 darkFrost  = mix(vec3(0.28), vec3(0.40), lum);
    vec3 lightFrost = vec3(1.0) - (vec3(1.0) - color) * (1.0 - tintStrength * 0.5);

    color = mix(
        mix(color, darkFrost, tintStrength),
        lightFrost,
        regime
    );

    // Subtle edge darkening near the perimeter
    float edgeShadowFactor = smoothstep(12.0, 0.0, distFromEdge) * edgeShadow;
    color *= (1.0 - edgeShadowFactor);

    // Border specular highlight
    float borderInner = smoothstep(2.5, 0.2, distFromEdge);
    float borderOuter = clamp(distFromEdge / (edgeAA * 0.8), 0.0, 1.0);
    float borderMask  = borderInner * borderOuter * aa;

    vec2 q2 = abs(localPos) - vec2(halfW, halfH) + cornerRadius;
    float lenQ2 = length(max(q2, 0.0));
    vec2 borderNormal = lenQ2 > 0.001
        ? sign(localPos) * max(q2, 0.0) / lenQ2
        : vec2(0.0);
    float dirFactor = abs(dot(borderNormal, normalize(vec2(0.7, 1.0))));
    dirFactor *= dirFactor;

    float borderBrightness = mix(0.6, 1.0, dirFactor);
    color = mix(color, vec3(borderBrightness), borderMask * 0.7);

    // Optional user tint overlay (v_Color.a controls strength)
    color = mix(color, v_Color.rgb, v_Color.a * 0.3);

    o_Color = vec4(color, aa * glassOpacity);
}
