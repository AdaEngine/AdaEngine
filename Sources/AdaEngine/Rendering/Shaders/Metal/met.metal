#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[ attribute(0) ]];
    float4 color;
};

struct Uniforms {
    float4x4 model;
    float4x4 view;
    float4x4 projection;
};

// Vertex shader outputs and fragment shader inputs
struct RasterizerData
{
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];
    
    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    float4 color;
};

vertex RasterizerData vertexFunction(
                                     uint vertexID [[vertex_id]],
                                     constant Vertex *vertices [[buffer(0)]],
                                     constant vector_uint2 *viewportSizePointer [[buffer(1)]],
                                     constant Uniforms &ubo [[buffer(2)]]
                                     ) {
    RasterizerData out;
    
    float2 position = vertices[vertexID].position.xy;
    
    out.position = ubo.model * ubo.projection * ubo.view * float4(float3(position.xy, 0), 1);
    // Pass the input color directly to the rasterizer.
    out.color = vertices[vertexID].color;
    
    return out;
}


fragment float4 fragmentFunction(RasterizerData in [[stage_in]]) {
    return in.color;
}
