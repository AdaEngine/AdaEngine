// Artistic grading shared by every pass that tone maps. Include with
// `#include <AdaEngine/ColorGrading.glsl>` inside a fragment stage.
//
// `adaApplyLut` reads two globals the including shader must declare before the include:
//   layout (binding = N) uniform texture2D u_GradingLUT;
//   layout (binding = M) uniform sampler u_GradingSampler;
// The LUT is a strip of N tiles (each N x N pixels, N*N wide and N tall): red along x inside a tile,
// green down the rows, blue selecting the tile. See ColorGrading3D on the Swift side.

// Saturation, contrast and vignette on linear HDR, before tone mapping.
// grading:  x saturation, y contrast, z vignette intensity, w vignette radius
// vignette: x vignette smoothness
vec3 adaGradeLinear(vec3 color, vec4 grading, vec4 vignette, vec2 uv) {
    if (grading.y != 1.0) {
        const float pivot = 0.18;
        color = pivot * pow(max(color, vec3(0.0)) / pivot, vec3(grading.y));
    }
    if (grading.x != 1.0) {
        float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
        color = max(mix(vec3(luma), color, grading.x), vec3(0.0));
    }
    if (grading.z > 0.0) {
        float corner = length((uv - 0.5) * 2.0) / 1.41421356;
        color *= 1.0 - grading.z * smoothstep(grading.w, grading.w + max(vignette.x, 0.01), corner);
    }
    return color;
}

vec3 adaSampleLutTile(vec3 color, float tile, float size) {
    vec2 texel = vec2(1.0 / (size * size), 1.0 / size);
    vec2 inTile = color.rg * (size - 1.0) + 0.5;
    return textureLod(sampler2D(u_GradingLUT, u_GradingSampler), vec2(tile * size + inTile.x, inTile.y) * texel, 0.0).rgb;
}

// Display-referred color through the LUT, blended by `intensity` (0 returns the input unchanged).
vec3 adaApplyLut(vec3 color, float intensity) {
    if (intensity <= 0.0) {
        return color;
    }
    float size = float(textureSize(sampler2D(u_GradingLUT, u_GradingSampler), 0).y);
    vec3 clamped = clamp(color, vec3(0.0), vec3(1.0));
    float blue = clamped.b * (size - 1.0);
    float lower = floor(blue);
    float upper = min(lower + 1.0, size - 1.0);
    vec3 graded = mix(adaSampleLutTile(clamped, lower, size), adaSampleLutTile(clamped, upper, size), blue - lower);
    return mix(color, graded, intensity);
}
