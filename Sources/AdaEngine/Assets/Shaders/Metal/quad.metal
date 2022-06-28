#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 view;
};

struct QuadVertex {
    float4 position [[ attribute(0) ]];
    float4 color [[ attribute(1) ]];
};

struct QuadVertexOut {
    float4 position [[ position ]];
    float4 color;
};

vertex QuadVertexOut quad_vertex(const QuadVertex vertexIn [[ stage_in ]], constant Uniforms &ubo [[ buffer(1) ]]) {
    float4 position = ubo.view * vertexIn.position;
                                      
    QuadVertexOut out {
        .position = position,
        .color = vertexIn.color
    };
                                      
    return out;
}

fragment float4 quad_fragment(QuadVertexOut in [[stage_in]]) {
    return in.color;
}

