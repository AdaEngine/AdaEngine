#include <metal_stdlib>
using namespace metal;




struct Vertex {
    float4 position [[ attribute(0) ]];
    float4 normal [[ attribute(1) ]];
    float2 uv [[ attribute(2) ]];
    float4 color [[ attribute(3) ]];
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
};

vertex RasterizerData vertex_main(
                                     Vertex vertexIn [[ stage_in ]],
                                     constant Uniforms &ubo [[ buffer(1) ]]
                                     ) {
    
    float4 position = ubo.model * ubo.view * ubo.projection * vertexIn.position;
    
    RasterizerData out {
        .position = position
    };
    
    return out;
}


fragment float4 fragment_main(RasterizerData in [[stage_in]]) {
    return float4(1, 0, 0, 1);
}
