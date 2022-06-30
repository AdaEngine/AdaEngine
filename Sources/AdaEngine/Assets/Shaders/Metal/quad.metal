#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 view;
};

struct QuadVertex {
    float4 position [[ attribute(0) ]];
    float4 color [[ attribute(1) ]];
    float2 textureCoordinate [[ attribute(2) ]];
};

struct QuadVertexOut {
    float4 position [[ position ]];
    float4 color;
    float2 textureCoordinate;
};

vertex QuadVertexOut quad_vertex(const QuadVertex vertexIn [[ stage_in ]], constant Uniforms &ubo [[ buffer(1) ]]) {
    float4 position = ubo.view * vertexIn.position;
                                      
    QuadVertexOut out {
        .position = position,
        .color = vertexIn.color,
        .textureCoordinate = vertexIn.textureCoordinate
    };
                                      
    return out;
}

fragment float4 quad_fragment(QuadVertexOut in [[stage_in]],
                              texture2d<half> colorTexture [[ texture(0) ]]) {
    
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    return float4(colorSample);
}

