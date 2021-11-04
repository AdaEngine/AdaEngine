#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[ attribute(0) ]];
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
    
    float4 position = ubo.projection * ubo.view * ubo.model * vertexIn.position;
    
    RasterizerData out {
        .position = position
    };
    
    return out;
}


fragment float4 fragment_main(RasterizerData in [[stage_in]]) {
    return float4(1, 0, 0, 1);
}
