#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 view;
};

struct SpriteVertex {
    float4 position [[ attribute(0) ]];
    float4 color [[ attribute(1) ]];
    float2 textureCoordinate [[ attribute(2) ]];
};

struct SpriteVertexOut {
    float4 position [[ position ]];
    float4 color;
    float2 textureCoordinate;
};

vertex SpriteVertexOut sprite_vertex(const SpriteVertex vertexIn [[ stage_in ]], constant Uniforms &ubo [[ buffer(1) ]]) {
    float4 position = ubo.view * vertexIn.position;
    
    SpriteVertexOut out {
        .position = position,
        .color = vertexIn.color,
        .textureCoordinate = vertexIn.textureCoordinate
    };
    
    return out;
}

fragment float4 sprite_fragment(SpriteVertexOut in [[stage_in]],
                              texture2d<half> texture [[ texture(0) ]],
                              sampler textureSampler [[ sampler(0) ]]
                              ) {
    
    const half4 colorSample = texture.sample(textureSampler, in.textureCoordinate);
    const float4 resultColor = float4(colorSample) * in.color;
    
    // to avoid depth write
    if (resultColor.a == 0.0) {
        discard_fragment();
    }
    
    return resultColor;
}

