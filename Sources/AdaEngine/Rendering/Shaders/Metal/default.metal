#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[ attribute(0) ]];
    float3 normal [[ attribute(1) ]];
//    float2 uv [[ attribute(2) ]];
//    float4 color [[ attribute(3) ]];
};

struct Uniforms {
    float4x4 model;
    float4x4 view;
    float4x4 projection;
};

// Vertex shader outputs and fragment shader inputs
struct RasterizerData
{
    float4 position [[position]];
    float3 wolrdPosition;
    float4 color;
};

vertex RasterizerData vertex_main(
                                     const Vertex vertexIn [[ stage_in ]],
                                     constant Uniforms &ubo [[ buffer(1) ]]
                                     ) {
    
    float4 position = ubo.projection * ubo.view * ubo.model * vertexIn.position;
    
    RasterizerData out {
        .position = position,
        .wolrdPosition = (ubo.model * vertexIn.position).xyz,
        .color = float4(1, 0, 0, 1)
    };
    
    return out;
}


fragment float4 fragment_main(RasterizerData in [[stage_in]]) {
    return in.color;
}
