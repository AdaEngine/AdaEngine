#include <metal_stdlib>
using namespace metal;

struct LineVertex {
    float3 position [[ attribute(0) ]];
    float4 color [[ attribute(1) ]];
    float lineWidth [[ attribute(2) ]];
};

struct Uniforms {
    float4x4 view;
};

// Vertex shader outputs and fragment shader inputs
struct LineVertexOut
{
    float4 position [[position]];
    float4 color;
};

vertex LineVertexOut line_vertex(const LineVertex vertexIn [[ stage_in ]], constant Uniforms &ubo [[ buffer(1) ]]) {
    float4 position = ubo.view * float4(vertexIn.position, 1.0);

    LineVertexOut out {
        .position = position,
        .color = vertexIn.color
    };

    return out;
}

fragment float4 line_fragment(LineVertexOut in [[stage_in]]) {
    return in.color;
}
