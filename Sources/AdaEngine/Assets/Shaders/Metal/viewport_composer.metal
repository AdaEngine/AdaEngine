#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 view;
};

struct VPVertex {
    float3 position [[ attribute(0) ]];
    float2 textureCoordinate [[ attribute(1) ]];
};

struct VPVertexOut {
    float4 position [[ position ]];
    float2 textureCoordinate;
};

vertex VPVertexOut vpcomposer_vertex(const VPVertex vertexIn [[ stage_in ]], constant Uniforms &ubo [[ buffer(1) ]]) {
    float4 position = ubo.view * float4(vertexIn.position, 1);
    
    VPVertexOut out {
        .position = position,
        .textureCoordinate = vertexIn.textureCoordinate,
    };
    
    return out;
}

fragment float4 vpcomposer_fragment(VPVertexOut in [[stage_in]],
                              texture2d<half> texture [[ texture(0) ]],
                              sampler textureSampler [[ sampler(0) ]]
                              ) {
    
    const half4 colorSample = texture.sample(textureSampler, in.textureCoordinate);
    const float4 resultColor = float4(colorSample);
    
    // to avoid depth write
    if (resultColor.a == 0.0) {
        discard_fragment();
    }
    
    return resultColor;
}
