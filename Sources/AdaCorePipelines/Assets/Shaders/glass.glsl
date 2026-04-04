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
const float kPI = 3.14159265;

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float sampleBlurredChannel(vec2 uv, vec2 texelSize, float radius, int channel) {
    if (radius < 0.5) {
        return texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), uv)[channel];
    }
    float value = texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), uv)[channel];
    float totalWeight = 1.0;
    for (int i = 1; i < kBlurSamples; i++) {
        float t = float(i) / float(kBlurSamples - 1);
        float r = sqrt(t) * radius;
        float theta = float(i) * kGoldenAngle;
        vec2 offset = vec2(cos(theta), sin(theta)) * r * texelSize;
        vec2 sampleUV = clamp(uv + offset, vec2(0.001), vec2(0.999));
        float weight = 1.0 - t * 0.7;
        value += texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), sampleUV)[channel] * weight;
        totalWeight += weight;
    }
    return value / totalWeight;
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

    float refractionStrength = 3.0;
    float edgeBandMultiplier = 0.3;
    float chromeStrength     = 0.5;

    ivec2 bgTexSizeI = textureSize(sampler2D(u_BackgroundTexture, u_BackgroundSampler), 0);
    vec2 bgTexSize = vec2(bgTexSizeI);
    vec2 texelSize = 1.0 / bgTexSize;

    vec2 localPos = (v_TexCoordinate - 0.5) * 2.0 * vec2(halfW, halfH);

    // SDF
    float sdf = sdRoundedBox(localPos, vec2(halfW, halfH), cornerRadius);
    float edgeAA = length(vec2(dFdx(sdf), dFdy(sdf)));
    edgeAA = max(edgeAA, 0.5);

    if (sdf > edgeAA * 2.0) {
        discard;
    }

    float distFromEdge = -sdf;
    float aa = clamp(0.5 - sdf / (edgeAA * 2.0), 0.0, 1.0);

    // ── Edge refraction band (OpenGlass-style) ──
    float effectiveSize = min(halfW * 2.0, halfH * 2.0);
    float edgeBand = effectiveSize * edgeBandMultiplier;
    float edgeFactor = 1.0 - smoothstep(0.0, edgeBand, distFromEdge);
    edgeFactor = edgeFactor * edgeFactor * edgeFactor * 2.0;

    // Direction toward nearest interior point on the rounded rect edge.
    float insetX = min(cornerRadius, halfW);
    float insetY = min(cornerRadius, halfH);
    vec2 center = vec2(0.0);
    float minX = -halfW + insetX;
    float maxX =  halfW - insetX;
    float minY = -halfH + insetY;
    float maxY =  halfH - insetY;
    vec2 nearestCenterPoint = vec2(
        clamp(localPos.x, minX, maxX),
        clamp(localPos.y, minY, maxY)
    );
    vec2 toCenter = nearestCenterPoint - localPos;
    float distToCenter = length(toCenter);
    toCenter = distToCenter > 0.001 ? toCenter / distToCenter : vec2(0.0);

    // Refraction displacement in pixels
    float disp = edgeFactor * refractionStrength * edgeBand;
    float chrome = edgeFactor * chromeStrength;

    vec2 greenOff = toCenter * disp;
    float blurPhysical = blurRadius * scaleFactor;

    vec2 baseBgUV = gl_FragCoord.xy / bgTexSize;

    // ── Sample with per-channel chromatic split ──
    vec3 color;
    if (chrome < 0.001) {
        vec2 uv = clamp(baseBgUV + greenOff * texelSize * scaleFactor, vec2(0.001), vec2(0.999));
        color = sampleBlurred(uv, texelSize, blurPhysical);
    } else {
        vec2 redOff   = toCenter * (disp + chrome);
        vec2 blueOff  = toCenter * (disp - chrome);

        vec2 redUV   = clamp(baseBgUV + redOff   * texelSize * scaleFactor, vec2(0.001), vec2(0.999));
        vec2 greenUV = clamp(baseBgUV + greenOff  * texelSize * scaleFactor, vec2(0.001), vec2(0.999));
        vec2 blueUV  = clamp(baseBgUV + blueOff   * texelSize * scaleFactor, vec2(0.001), vec2(0.999));

        color.r = sampleBlurredChannel(redUV,   texelSize, blurPhysical, 0);
        color.g = sampleBlurredChannel(greenUV,  texelSize, blurPhysical, 1);
        color.b = sampleBlurredChannel(blueUV,   texelSize, blurPhysical, 2);
    }

    float lum = dot(color, vec3(0.299, 0.587, 0.114));

    // ── Frosted tinting ──
    float regime = smoothstep(0.35, 0.65, lum);

    vec3 darkFrost  = mix(vec3(0.28), vec3(0.40), lum);
    vec3 lightFrost = vec3(1.0) - (vec3(1.0) - color) * (1.0 - tintStrength * 0.5);

    color = mix(
        mix(color, darkFrost, tintStrength),
        lightFrost,
        regime
    );

    // ── Inner glow ──
    vec2 normPos = localPos / vec2(halfW, halfH);
    float radialDist = length(normPos);
    float glowMask = (1.0 - radialDist) * (1.0 - radialDist);
    float topBias = clamp(1.0 - normPos.y * 0.6, 0.0, 1.0);
    color += vec3(0.04, 0.045, 0.055) * glowMask * topBias * tintStrength;

    // ── Edge shadow ──
    float shadowScale = clamp(1.0 - lum * 0.8, 0.0, 1.0);
    float edgeShadowFactor = smoothstep(20.0, 0.0, distFromEdge) * edgeShadow * shadowScale;
    color *= (1.0 - edgeShadowFactor);

    // ── Specular border highlight ──
    float borderInner = smoothstep(3.0, 0.3, distFromEdge);
    float borderOuter = clamp(distFromEdge / (edgeAA * 0.8), 0.0, 1.0);
    float borderMask  = borderInner * borderOuter * aa;

    vec2 q2 = abs(localPos) - vec2(halfW, halfH) + cornerRadius;
    vec2 borderNormal;
    if (max(q2.x, q2.y) < 0.0) {
        borderNormal = (q2.x > q2.y)
            ? vec2(sign(localPos.x), 0.0)
            : vec2(0.0, sign(localPos.y));
    } else {
        vec2 w = max(q2, 0.0);
        float len = length(w);
        borderNormal = len > 0.001 ? sign(localPos) * w / len : vec2(0.0);
    }

    vec2 lightDir = normalize(vec2(1.0, 1.0));
    float dirFactor = abs(dot(borderNormal, lightDir));
    dirFactor *= dirFactor;

    float borderDark  = mix(0.10, 0.40, dirFactor);
    float borderLight = mix(0.62, 1.0, dirFactor) * mix(0.65, 1.0, lum);
    float borderBase  = mix(borderDark, borderLight, regime);
    color = mix(color, vec3(1.0), borderMask * borderBase);

    // Optional user tint overlay
    color = mix(color, v_Color.rgb, v_Color.a * 0.3);

    o_Color = vec4(color, aa * glassOpacity);
}
