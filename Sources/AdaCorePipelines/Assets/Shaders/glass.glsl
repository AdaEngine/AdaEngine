#version 450 core
#pragma stage : vert

#include <AdaEngine/View.glsl>

layout (location = 0) in vec4 a_Position;
layout (location = 1) in vec4 a_Color;
layout (location = 2) in vec2 a_TexCoordinate;
layout (location = 3) in vec4 a_GlassParams;   // x=blurRadius, y=cornerRadius, z=tintStrength, w=edgeShadow
layout (location = 4) in vec4 a_GlassInfo;     // x=halfWidth, y=halfHeight, z=scaleFactor, w=opacity

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
layout (location = 2) in vec4 v_GlassParams;
layout (location = 3) in vec4 v_GlassInfo;

layout (binding = 0) uniform texture2D u_BackgroundTexture;
layout (binding = 1) uniform sampler u_BackgroundSampler;

// Inspired by LiquidGlassKit: dispersion indices (small channel-relative UV shift).
const float kRefractR = 1.0 - 0.02;
const float kRefractG = 1.0;
const float kRefractB = 1.0 + 0.02;

const float kGoldenAngle = 2.39996323;
const int kBlurSamples = 32;

const float kDispersionIORRed = 1.0 - 0.02;
const float kDispersionIORGreen = 1.0;
const float kDispersionIORBlue = 1.0 + 0.02;

float saturate(float value) {
    return clamp(value, 0.0, 1.0);
}

vec2 saturate(vec2 value) {
    return clamp(value, vec2(0.0), vec2(1.0));
}

float superellipseCornerSDF(vec2 point, float radius, float exponent) {
    vec2 absPoint = abs(point);
    float value = pow(pow(absPoint.x, exponent) + pow(absPoint.y, exponent), 1.0 / exponent);
    return value - radius;
}

float roundedSuperellipseRectSDF(vec2 point, vec2 halfExtents, float cornerRadius, float exponent) {
    float clampedRadius = min(cornerRadius, min(halfExtents.x, halfExtents.y));
    vec2 edgeDistance = abs(point) - halfExtents;

    if (edgeDistance.x > -clampedRadius && edgeDistance.y > -clampedRadius) {
        vec2 cornerCenter = sign(point) * (halfExtents - vec2(clampedRadius));
        return superellipseCornerSDF(point - cornerCenter, clampedRadius, exponent);
    }

    return min(max(edgeDistance.x, edgeDistance.y), 0.0) + length(max(edgeDistance, vec2(0.0)));
}

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float blurWeight(float t) {
    return 1.0 - t * 0.7;
}

vec4 sampleBg(vec2 uv) {
    return texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), uv);
}

float sampleBlurredChannel(vec2 uv, vec2 texelSize, float radius, int channel) {
    vec2 clampedUV = clamp(uv, vec2(0.001), vec2(0.999));

    if (radius < 0.5) {
        return sampleBg(uv)[channel];
    }
    float value = sampleBg(uv)[channel];
    float totalWeight = 1.0;

    for (int i = 1; i < kBlurSamples; i++) {
        float t = float(i) / float(kBlurSamples - 1);
        float r = sqrt(t) * radius;
        float theta = float(i) * kGoldenAngle;
        vec2 offset = vec2(cos(theta), sin(theta)) * r * texelSize;
        vec2 sampleUV = clamp(uv + offset, vec2(0.001), vec2(0.999));
        float weight = 1.0 - t * 0.7;
        value += sampleBg(sampleUV)[channel] * weight;
        totalWeight += weight;
    }

    return value / totalWeight;
}

// Per-channel blur + dispersion (LiquidGlassKit sampleWithDispersion).
vec3 sampleBlurredDispersed(
    vec2 baseUv,
    vec2 texelSize,
    float radius,
    vec2 offsetUv,
    float dispersionFactor
) {
    vec2 oR = offsetUv * (1.0 - (kRefractR - 1.0) * dispersionFactor);
    vec2 oG = offsetUv * (1.0 - (kRefractG - 1.0) * dispersionFactor);
    vec2 oB = offsetUv * (1.0 - (kRefractB - 1.0) * dispersionFactor);
    vec2 uvR = clamp(baseUv + oR, vec2(0.001), vec2(0.999));
    vec2 uvG = clamp(baseUv + oG, vec2(0.001), vec2(0.999));
    vec2 uvB = clamp(baseUv + oB, vec2(0.001), vec2(0.999));
    float r = sampleBlurredChannel(uvR, texelSize, radius, 0);
    float g = sampleBlurredChannel(uvG, texelSize, radius, 1);
    float b = sampleBlurredChannel(uvB, texelSize, radius, 2);
    return vec3(r, g, b);
}

float shapeDistanceNormalized(float sdf, float scaleFactor, float pixelHeight) {
    return sdf * scaleFactor / max(pixelHeight, 1.0);
}

[[main]]
void glass_fragment() {
    float blurRadius = v_GlassParams.x;
    float cornerRadius = v_GlassParams.y;
    float tintStrength = v_GlassParams.z;
    float edgeShadow = v_GlassParams.w;

    float halfW = v_GlassInfo.x;
    float halfH = v_GlassInfo.y;
    float scaleFactor = max(v_GlassInfo.z, 1.0);
    float glassOpacity = saturate(v_GlassInfo.w);

    ivec2 bgTexSizeI = textureSize(sampler2D(u_BackgroundTexture, u_BackgroundSampler), 0);
    vec2 bgTexSize = vec2(bgTexSizeI);
    vec2 texelSize = 1.0 / bgTexSize;
    vec2 logicalResolution = bgTexSize / scaleFactor;

    vec2 localPos = (v_TexCoordinate - 0.5) * 2.0 * vec2(halfW, halfH);
    vec2 halfExtents = vec2(halfW, halfH);
    float cornerRoundnessExponent = max(4.0, 2.0);
    float sdf = roundedSuperellipseRectSDF(localPos, halfExtents, cornerRadius, cornerRoundnessExponent);

    float edgeAA = max(length(vec2(dFdx(sdf), dFdy(sdf))), 0.75 / scaleFactor);
    float alpha = 1.0 - smoothstep(-edgeAA, edgeAA, sdf);
    if (alpha <= 0.0 || glassOpacity <= 0.0) {
        discard;
    }

    float distFromEdge = -sdf;

    // Gradient of SDF in logical space → inward refraction direction (LiquidGlass-style).
    const float kGradEps = 1.0;
    float hx = sdRoundedBox(localPos + vec2(kGradEps, 0.0), vec2(halfW, halfH), cornerRadius)
             - sdRoundedBox(localPos - vec2(kGradEps, 0.0), vec2(halfW, halfH), cornerRadius);
    float hy = sdRoundedBox(localPos + vec2(0.0, kGradEps), vec2(halfW, halfH), cornerRadius)
             - sdRoundedBox(localPos - vec2(0.0, kGradEps), vec2(halfW, halfH), cornerRadius);
    vec2 grad = vec2(hx, hy);
    float glen = length(grad);
    vec2 inward = glen > 1e-4 ? -grad / glen : vec2(0.0, 1.0);

    float effectiveSize = min(halfW * 2.0, halfH * 2.0);
    float edgeBand = max(effectiveSize * 0.28, 1.0);
    float edgeFactor = 1.0 - smoothstep(0.0, edgeBand, distFromEdge);
    edgeFactor = edgeFactor * edgeFactor;

    // Base edge refraction (higher floor so .clear still bends background).
    float refractionPx = mix(3.0, 14.0, tintStrength) * scaleFactor;
    vec2 refractEdge = inward * texelSize * refractionPx * edgeFactor;

    // Radial barrel: pr² + pr term so warping is visible away from the exact center.
    vec2 pNorm = vec2(localPos.x / max(halfW, 1e-4), localPos.y / max(halfH, 1e-4));
    float pr = length(pNorm);
    vec2 pDir = pr > 1e-4 ? pNorm / pr : vec2(0.0);
    float pr2 = pr * pr;
    float lensPx = mix(12.0, 34.0, tintStrength) * scaleFactor;
    vec2 refractInterior = pDir * (pr2 * 1.1 + pr * 0.42) * lensPx * texelSize;

    // Thick-glass rim: strongest near inner perimeter (reference: lines "pulled" along curved edge).
    float minSidePx = max(min(halfW, halfH), 1.0);
    float rimW = max(minSidePx * 0.4, 6.0);
    float rim01 = 1.0 - smoothstep(0.0, rimW, distFromEdge);
    float rim = rim01 * rim01 * rim01;
    vec2 toCenter = length(localPos) > 1e-3 ? -localPos / length(localPos) : vec2(0.0, 1.0);
    float rimLensPx = mix(18.0, 44.0, tintStrength) * scaleFactor;
    vec2 refractRim = toCenter * rim * rimLensPx * texelSize;

    vec2 refractUvOffset = refractEdge + refractInterior + refractRim;

    float dispersionFactor = clamp(
        edgeFactor * mix(0.35, 1.0, tintStrength)
            + rim * mix(0.45, 0.95, tintStrength)
            + pr2 * mix(0.25, 0.6, tintStrength),
        0.0,
        1.0
    );

    float blurPhysical = max(blurRadius * scaleFactor, 1.5);

    // Normalized UV into the captured framebuffer (same convention as Main2D + blit).
    vec2 baseBgUV = gl_FragCoord.xy / bgTexSize;
    baseBgUV = clamp(baseBgUV, vec2(0.001), vec2(0.999));

    vec3 color = sampleBlurredDispersed(
        baseBgUV,
        texelSize,
        blurPhysical,
        refractUvOffset,
        dispersionFactor
    );

    // Subtle cool tint; keep light for "clear" even when tintStrength drives lens strength.
    vec3 cooled = mix(color, color * vec3(0.94, 0.96, 1.04), tintStrength * 0.28);
    color = mix(color, cooled, tintStrength * 0.85);
    color *= mix(1.0, 0.93, tintStrength * 0.18);

    // Fresnel rim (brightness toward edges), not full plastic fill.
    float minSide = max(min(halfW, halfH), 1.0);
    float edgeT = clamp(distFromEdge / (minSide * 0.45 + 1.0), 0.0, 1.0);
    float fresnel = pow(1.0 - edgeT, 3.2) * mix(0.12, 0.42, tintStrength);
    vec3 rimLight = mix(vec3(1.0), color, 0.35);
    color = mix(color, rimLight, fresnel);

    // Specular streak along top-left light (subtle).
    vec2 nrm = vec2(halfW > 0.0 ? localPos.x / halfW : 0.0, halfH > 0.0 ? localPos.y / halfH : 0.0);
    float spec = pow(max(0.0, dot(normalize(vec2(1.0, 1.3)), normalize(nrm + vec2(0.01))), 8.0);
    spec *= (1.0 - edgeT) * tintStrength * 0.22;
    color += vec3(spec);

    // Inner vignette (not grey slab).
    float radial = length(nrm);
    color *= mix(1.0, 0.94 + 0.06 * radial, tintStrength * 0.4);

    // Edge shadow (existing API: edgeShadowStrength).
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    float shadowScale = clamp(1.0 - lum * 0.75, 0.0, 1.0);
    float edgeShadowFactor = smoothstep(24.0, 0.0, distFromEdge) * edgeShadow * shadowScale;
    color *= (1.0 - edgeShadowFactor);

    // Optional user tint (unchanged API: alpha scales blend).
    color = mix(color, v_Color.rgb, v_Color.a * 0.3);

    o_Color = vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha * glassOpacity);
}