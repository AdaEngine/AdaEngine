#version 450 core
#pragma stage : vert

#include <AdaEngine/View.glsl>

layout (location = 0) in vec4 a_Position;
layout (location = 1) in vec4 a_Color;
layout (location = 2) in vec2 a_TexCoordinate;
layout (location = 3) in vec4 a_GlassParams0;
layout (location = 4) in vec4 a_GlassParams1;
layout (location = 5) in vec4 a_GlassParams2;
layout (location = 6) in vec4 a_GlassParams3;
layout (location = 7) in vec4 a_GlassInfo0;
layout (location = 8) in vec4 a_GlassInfo1;

layout (location = 0) out vec4 v_Color;
layout (location = 1) out vec2 v_TexCoordinate;
layout (location = 2) out vec4 v_GlassParams0;
layout (location = 3) out vec4 v_GlassParams1;
layout (location = 4) out vec4 v_GlassParams2;
layout (location = 5) out vec4 v_GlassParams3;
layout (location = 6) out vec4 v_GlassInfo0;
layout (location = 7) out vec4 v_GlassInfo1;

[[main]]
void glass_vertex() {
    v_Color = a_Color;
    v_TexCoordinate = a_TexCoordinate;
    v_GlassParams0 = a_GlassParams0;
    v_GlassParams1 = a_GlassParams1;
    v_GlassParams2 = a_GlassParams2;
    v_GlassParams3 = a_GlassParams3;
    v_GlassInfo0 = a_GlassInfo0;
    v_GlassInfo1 = a_GlassInfo1;
    gl_Position = u_ViewProjection * a_Position;
}

#version 450 core
#pragma stage : frag

layout (location = 0) out vec4 o_Color;

layout (location = 0) in vec4 v_Color;
layout (location = 1) in vec2 v_TexCoordinate;
layout (location = 2) in vec4 v_GlassParams0;
layout (location = 3) in vec4 v_GlassParams1;
layout (location = 4) in vec4 v_GlassParams2;
layout (location = 5) in vec4 v_GlassParams3;
layout (location = 6) in vec4 v_GlassInfo0;
layout (location = 7) in vec4 v_GlassInfo1;

layout (binding = 0) uniform texture2D u_BackgroundTexture;
layout (binding = 1) uniform sampler u_BackgroundSampler;

const float kPI = 3.14159265;
const float kBlurGoldenAngle = 2.39996323;
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

float blurWeight(float t) {
    return 1.0 - t * 0.7;
}

float sampleBlurredChannel(vec2 uv, vec2 texelSize, float radius, int channel) {
    vec2 clampedUV = clamp(uv, vec2(0.001), vec2(0.999));

    if (radius < 0.5) {
        return texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), clampedUV)[channel];
    }

    float value = texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), clampedUV)[channel];
    float totalWeight = 1.0;

    for (int i = 1; i < kBlurSamples; i++) {
        float t = float(i) / float(kBlurSamples - 1);
        float r = sqrt(t) * radius;
        float theta = float(i) * kBlurGoldenAngle;
        vec2 offset = vec2(cos(theta), sin(theta)) * r * texelSize;
        vec2 sampleUV = clamp(clampedUV + offset, vec2(0.001), vec2(0.999));
        float weight = blurWeight(t);
        value += texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), sampleUV)[channel] * weight;
        totalWeight += weight;
    }

    return value / totalWeight;
}

float dispersionScaleForChannel(int channel, float dispersionStrength) {
    float refractiveIndex = kDispersionIORGreen;

    if (channel == 0) {
        refractiveIndex = kDispersionIORRed;
    } else if (channel == 2) {
        refractiveIndex = kDispersionIORBlue;
    }

    return 1.0 - (refractiveIndex - 1.0) * dispersionStrength;
}

vec3 sampleBlurredDispersion(vec2 baseUV, vec2 texelSize, float blurRadius, vec2 offset, float dispersionStrength) {
    vec3 color = vec3(0.0);

    for (int channel = 0; channel < 3; channel++) {
        float dispersionScale = dispersionScaleForChannel(channel, dispersionStrength);
        vec2 shiftedUV = baseUV + offset * dispersionScale;
        color[channel] = sampleBlurredChannel(shiftedUV, texelSize, blurRadius, channel);
    }

    return color;
}

float shapeDistanceNormalized(float sdf, float scaleFactor, float pixelHeight) {
    return sdf * scaleFactor / max(pixelHeight, 1.0);
}

vec2 computeSurfaceNormal(vec2 localPos, vec2 halfExtents, float cornerRadius, float exponent, float scaleFactor, float pixelHeight) {
    float epsilon = max(0.75, 0.5 / max(scaleFactor, 1.0));
    float dx = shapeDistanceNormalized(
        roundedSuperellipseRectSDF(localPos + vec2(epsilon, 0.0), halfExtents, cornerRadius, exponent),
        scaleFactor,
        pixelHeight
    ) - shapeDistanceNormalized(
        roundedSuperellipseRectSDF(localPos - vec2(epsilon, 0.0), halfExtents, cornerRadius, exponent),
        scaleFactor,
        pixelHeight
    );
    float dy = shapeDistanceNormalized(
        roundedSuperellipseRectSDF(localPos + vec2(0.0, epsilon), halfExtents, cornerRadius, exponent),
        scaleFactor,
        pixelHeight
    ) - shapeDistanceNormalized(
        roundedSuperellipseRectSDF(localPos - vec2(0.0, epsilon), halfExtents, cornerRadius, exponent),
        scaleFactor,
        pixelHeight
    );

    return vec2(dx, dy) / (2.0 * epsilon) * 1414.213562;
}

float linearizeSRGB(float channel) {
    return channel > 0.04045 ? pow((channel + 0.055) / 1.055, 2.4) : channel / 12.92;
}

float gammaCorrectSRGB(float linear) {
    return linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1.0 / 2.4) - 0.055;
}

vec3 srgbToLinear(vec3 color) {
    return vec3(
        linearizeSRGB(color.r),
        linearizeSRGB(color.g),
        linearizeSRGB(color.b)
    );
}

vec3 linearToSrgb(vec3 color) {
    return vec3(
        gammaCorrectSRGB(color.r),
        gammaCorrectSRGB(color.g),
        gammaCorrectSRGB(color.b)
    );
}

vec3 srgbToXyz(vec3 srgb) {
    vec3 linear = srgbToLinear(srgb);
    mat3 rgbToXyz = mat3(
        0.4124, 0.2126, 0.0193,
        0.3576, 0.7152, 0.1192,
        0.1805, 0.0722, 0.9505
    );
    return rgbToXyz * linear;
}

float xyzToLabNonlinear(float value) {
    return value > 0.00885645167 ? pow(value, 1.0 / 3.0) : 7.78703703704 * value + 0.13793103448;
}

vec3 xyzToLab(vec3 xyz) {
    vec3 whiteReference = vec3(0.95045592705, 1.0, 1.08905775076);
    vec3 scaled = xyz / whiteReference;
    scaled = vec3(
        xyzToLabNonlinear(scaled.x),
        xyzToLabNonlinear(scaled.y),
        xyzToLabNonlinear(scaled.z)
    );

    return vec3(
        116.0 * scaled.y - 16.0,
        500.0 * (scaled.x - scaled.y),
        200.0 * (scaled.y - scaled.z)
    );
}

vec3 srgbToLab(vec3 srgb) {
    return xyzToLab(srgbToXyz(srgb));
}

vec3 labToLch(vec3 lab) {
    float chroma = sqrt(dot(lab.yz, lab.yz));
    float hue = degrees(atan(lab.z, lab.y));
    return vec3(lab.x, chroma, hue);
}

vec3 srgbToLch(vec3 srgb) {
    return labToLch(srgbToLab(srgb));
}

float labToXyzNonlinear(float transformed) {
    return transformed > 0.206897 ? transformed * transformed * transformed : 0.12841854934 * (transformed - 0.137931034);
}

vec3 labToXyz(vec3 lab) {
    vec3 whiteReference = vec3(0.95045592705, 1.0, 1.08905775076);
    float whiteScaled = (lab.x + 16.0) / 116.0;
    return whiteReference * vec3(
        labToXyzNonlinear(whiteScaled + lab.y / 500.0),
        labToXyzNonlinear(whiteScaled),
        labToXyzNonlinear(whiteScaled - lab.z / 200.0)
    );
}

vec3 xyzToSrgb(vec3 xyz) {
    mat3 xyzToRgb = mat3(
         3.2406255, -0.9689307,  0.0557101,
        -1.5372080,  1.8757561, -0.2040211,
        -0.4986286,  0.0415175,  1.0569959
    );
    return linearToSrgb(xyzToRgb * xyz);
}

vec3 labToSrgb(vec3 lab) {
    return xyzToSrgb(labToXyz(lab));
}

vec3 lchToLab(vec3 lch) {
    float hue = radians(lch.z);
    return vec3(lch.x, lch.y * cos(hue), lch.y * sin(hue));
}

vec3 lchToSrgb(vec3 lch) {
    return labToSrgb(lchToLab(lch));
}

float vectorToAngle(vec2 vector) {
    float angle = atan(vector.y, vector.x);
    return angle < 0.0 ? angle + 2.0 * kPI : angle;
}

[[main]]
void glass_fragment() {
    float blurRadius = v_GlassParams0.x;
    float cornerRadius = v_GlassParams0.y;
    float tintStrength = v_GlassParams0.z;
    float edgeShadowStrength = v_GlassParams0.w;

    float cornerRoundnessExponent = max(v_GlassParams1.x, 2.0);
    float glassThickness = max(v_GlassParams1.y, 0.0);
    float refractiveIndex = max(v_GlassParams1.z, 1.0);
    float dispersionStrength = max(v_GlassParams1.w, 0.0);

    float fresnelDistanceRange = max(v_GlassParams2.x, 1.0);
    float fresnelIntensity = max(v_GlassParams2.y, 0.0);
    float fresnelEdgeSharpness = v_GlassParams2.z;
    float glareDistanceRange = max(v_GlassParams2.w, 1.0);

    float glareAngleConvergence = max(v_GlassParams3.x, 0.0);
    float glareOppositeSideBias = max(v_GlassParams3.y, 0.0);
    float glareIntensity = max(v_GlassParams3.z, 0.0);
    float glareEdgeSharpness = v_GlassParams3.w;

    float halfW = v_GlassInfo0.x;
    float halfH = v_GlassInfo0.y;
    float scaleFactor = max(v_GlassInfo0.z, 1.0);
    float glassOpacity = saturate(v_GlassInfo0.w);
    float glareDirectionOffset = v_GlassInfo1.x;

    ivec2 bgTexSizeI = textureSize(sampler2D(u_BackgroundTexture, u_BackgroundSampler), 0);
    vec2 bgTexSize = vec2(bgTexSizeI);
    vec2 texelSize = 1.0 / bgTexSize;
    vec2 logicalResolution = bgTexSize / scaleFactor;

    vec2 localPos = (v_TexCoordinate - 0.5) * 2.0 * vec2(halfW, halfH);
    vec2 halfExtents = vec2(halfW, halfH);
    float sdf = roundedSuperellipseRectSDF(localPos, halfExtents, cornerRadius, cornerRoundnessExponent);

    float edgeAA = max(length(vec2(dFdx(sdf), dFdy(sdf))), 0.75 / scaleFactor);
    float alpha = 1.0 - smoothstep(-edgeAA, edgeAA, sdf);
    if (alpha <= 0.0 || glassOpacity <= 0.0) {
        discard;
    }

    float shapeDistance = shapeDistanceNormalized(sdf, scaleFactor, bgTexSize.y);
    float normalizedDepth = -shapeDistance * logicalResolution.y;

    vec2 baseUv = clamp(gl_FragCoord.xy / bgTexSize, vec2(0.001), vec2(0.999));
    vec2 surfaceNormal = computeSurfaceNormal(localPos, halfExtents, cornerRadius, cornerRoundnessExponent, scaleFactor, bgTexSize.y);
    float normalMagnitude = length(surfaceNormal);
    vec2 safeNormal = normalMagnitude > 0.0001 ? surfaceNormal / normalMagnitude : vec2(0.0, -1.0);

    float depthRatio = glassThickness > 0.0 ? 1.0 - normalizedDepth / glassThickness : 0.0;
    depthRatio = saturate(depthRatio);

    float incidentAngle = asin(saturate(depthRatio * depthRatio));
    float transmittedAngle = asin(clamp((1.0 / refractiveIndex) * sin(incidentAngle), -1.0, 1.0));
    float edgeShiftFactor = -tan(transmittedAngle - incidentAngle);
    if (normalizedDepth >= glassThickness) {
        edgeShiftFactor = 0.0;
    }

    vec2 offsetUv = -safeNormal * edgeShiftFactor * 0.05 * scaleFactor * vec2(
        bgTexSize.y / max(logicalResolution.x * scaleFactor, 1.0),
        1.0
    );

    float edgeBand = max(glassThickness, 1.0);
    float edgeMask = 1.0 - smoothstep(0.0, edgeBand, normalizedDepth);
    float innerMask = smoothstep(0.5, edgeBand * 0.7, normalizedDepth);
    float borderMask = edgeMask * (1.0 - smoothstep(0.0, max(edgeBand * 0.45, 1.0), normalizedDepth));

    float localBlur = min(max(blurRadius * scaleFactor * 0.18, 0.0), 1.35) * (0.18 + edgeMask * 0.82);
    vec3 background = texture(sampler2D(u_BackgroundTexture, u_BackgroundSampler), baseUv).rgb;
    vec3 refracted = sampleBlurredDispersion(baseUv, texelSize, localBlur, offsetUv * edgeMask, dispersionStrength * edgeMask);

    vec3 tintColor = v_Color.a > 0.0 ? v_Color.rgb : vec3(0.97, 0.985, 1.0);
    float tintMix = tintStrength * (0.05 + innerMask * 0.16);
    vec3 color = mix(background, refracted, edgeMask);
    color = mix(color, tintColor, tintMix);

    float fresnelValue = clamp(
        pow(
            1.0 + shapeDistance * logicalResolution.y / 1500.0 * pow(500.0 / fresnelDistanceRange, 2.0) + fresnelEdgeSharpness,
            5.0
        ),
        0.0,
        1.0
    );
    vec3 fresnelBaseTint = mix(vec3(1.0), tintColor, tintMix * 0.5);
    vec3 fresnelLch = srgbToLch(clamp(fresnelBaseTint, vec3(0.0), vec3(1.0)));
    fresnelLch.x = clamp(fresnelLch.x + 20.0 * fresnelValue * fresnelIntensity, 0.0, 100.0);
    color = mix(
        color,
        clamp(lchToSrgb(fresnelLch), vec3(0.0), vec3(1.0)),
        saturate(fresnelValue * fresnelIntensity * 0.75 * edgeMask * min(normalMagnitude, 1.0))
    );

    float glareGeometryValue = clamp(
        pow(
            1.0 + shapeDistance * logicalResolution.y / 1500.0 * pow(500.0 / glareDistanceRange, 2.0) + glareEdgeSharpness,
            5.0
        ),
        0.0,
        1.0
    );
    float glareAngle = (vectorToAngle(safeNormal) - kPI / 4.0 + glareDirectionOffset) * 2.0;
    bool isFarSide = ((glareAngle > kPI * 1.5 && glareAngle < kPI * 3.5) || glareAngle < -kPI * 0.5);
    float angularGlare = (0.5 + sin(glareAngle) * 0.5)
        * (isFarSide ? 1.2 * glareOppositeSideBias : 1.2)
        * glareIntensity;
    angularGlare = clamp(pow(max(angularGlare, 0.0), 0.1 + glareAngleConvergence * 2.0), 0.0, 1.0);

    vec3 baseGlare = mix(refracted, tintColor, tintMix * 0.5);
    vec3 glareLch = srgbToLch(clamp(baseGlare, vec3(0.0), vec3(1.0)));
    glareLch.x = clamp(glareLch.x + 150.0 * angularGlare * glareGeometryValue, 0.0, 120.0);
    glareLch.y = clamp(glareLch.y + 30.0 * angularGlare * glareGeometryValue, 0.0, 150.0);
    color = mix(
        color,
        clamp(lchToSrgb(glareLch), vec3(0.0), vec3(1.0)),
        saturate(angularGlare * glareGeometryValue * edgeMask * min(normalMagnitude, 1.0))
    );

    if (edgeShadowStrength > 0.0) {
        float edgeShadow = smoothstep(10.0 / scaleFactor, 0.0, -sdf) * edgeShadowStrength;
        color *= 1.0 - edgeShadow * 0.35;
    }

    float verticalSheen = pow(1.0 - v_TexCoordinate.y, 2.6) * 0.12;
    float centerLift = pow(1.0 - abs(v_TexCoordinate.x - 0.5) * 2.0, 2.0) * 0.05;
    color += vec3(1.0) * (verticalSheen * 0.55 + centerLift * 0.35) * innerMask;
    color += vec3(1.0) * borderMask * 0.18;

    o_Color = vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha * glassOpacity);
}
