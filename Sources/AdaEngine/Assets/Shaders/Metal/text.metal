#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 view;
};

struct TextVertex {
    float4 position [[ attribute(0) ]];
    float4 color [[ attribute(1) ]];
    float2 textureCoordinate [[ attribute(2) ]];
    float2 textureSize [[ attribute(3) ]]
    int textureIndex [[ attribute(4) ]];
};

struct TextVertexOut {
    float4 position [[ position ]];
    float4 color;
    float2 textureCoordinate;
    float2 textureSize;
    int textureIndex;
};

vertex TextVertexOut text_vertex(const TextVertex vertexIn [[ stage_in ]], constant Uniforms &ubo [[ buffer(1) ]]) {
    float4 position = ubo.view * vertexIn.position;
    
    TextVertexOut out {
        .position = position,
        .color = vertexIn.color,
        .textureCoordinate = vertexIn.textureCoordinate,
        .textureSize = vertexIn.textureSize,
        .textureIndex = vertexIn.textureIndex
    };
    
    return out;
}

fragment float4 text_fragment(TextVertexOut in [[stage_in]],
                              array<texture2d<half>, 32> textures [[ texture(0) ]],
                              sampler textureSampler [[ sampler(0) ]]
                              ) {
    const float4 bgColor = float4(in.color, 0.0);
    const float4 fgColor = in.color;
    
    const texture2d<half> texture = textures[in.textureIndex];
    const half4 msd = texture.sample(textureSampler, in.textureCoordinate);
    float sd = median(msd.rgb);
    float px_Distance = screen_px_range(texture, in.textureSize, in.textureCoordinate) * (sd - 0.5f);
    float opacity = clamp(px_Distance + 0.5, 0.0, 1.0)
    const float4 resultColor = mix(bgColor, fgColor, float4(opacity));
    
    return resultColor;
}

float screen_px_range(texture2d<half> texture, float2 textureSize, float2 textureCoordinate) {
    const float pxRange = 2.0f;
    const float2 unitRange = float2(pxRange) / textureSize;
    const float2 screenTexSize = float2(1.0) / fwidth(textureCoordinate);
    return max(0.5 * dot(unitRange, screenTexSize), 1.0);
}

float median(const float3& rgb) {
    return max(min(rgb.r, rgb.g), min(max(rgb.r, rgb.g), rgb.b);
}
