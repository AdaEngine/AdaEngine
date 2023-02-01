#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 view;
};

struct CircleVertex {
    float4 worldPosition [[ attribute(0) ]];
    float3 localPosition [[ attribute(1) ]];
    float thickness [[ attribute(2) ]];
    float fade [[ attribute(3) ]];
    float4 color [[ attribute(4) ]];
};

struct CircleVertexOut {
    float4 position [[ position ]];
    float3 localPosition;
    float fade;
    float thickness;
    float4 color;
};

vertex CircleVertexOut circle_vertex(const CircleVertex vertexIn [[ stage_in ]], constant Uniforms &ubo [[ buffer(1) ]]) {
    float4 position = ubo.view * vertexIn.worldPosition;
    
    CircleVertexOut out {
        .position = position,
        .fade = vertexIn.fade,
        .thickness = vertexIn.thickness,
        .localPosition = vertexIn.localPosition,
        .color = vertexIn.color
    };
    
    return out;
}

fragment float4 circle_fragment(CircleVertexOut in [[stage_in]]) {
    float distance = 1.0 - length(in.localPosition);
    float circle = smoothstep(0.0, in.fade, distance);
    circle *= smoothstep(in.thickness + in.fade, in.thickness, distance);
    
    float4 color = in.color;
    if (circle == 0.0)
        discard_fragment();
    
    // Set output color
    color.a *= circle;
    
    return color;
}
