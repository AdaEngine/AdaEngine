#version 450 core
#pragma stage : vert

#include <AdaEngine/View.glsl>

layout (location = 0) in vec4 a_Position;
layout (location = 1) in vec4 a_Color;
layout (location = 2) in vec2 a_TexCoordinate;

struct VertexOut
{
    vec4 Color;
    vec2 TexCoordinate;
};

layout (location = 0) out VertexOut Output;

[[main]]
void quad_vertex()
{
    Output.Color = a_Color;
    Output.TexCoordinate = a_TexCoordinate;
    
    gl_Position = u_ViewProjection * a_Position;
}

#version 450 core
#pragma stage : frag

layout (location = 0) out vec4 color;

struct VertexOut
{
    vec4 Color;
    vec2 TexCoordinate;
};

layout (location = 0) in VertexOut Input;
layout (binding = 0) uniform texture2D u_Texture;
layout (binding = 1) uniform sampler u_TextureSampler;

[[main]]
void quad_fragment()
{
    color = texture(sampler2D(u_Texture, u_TextureSampler), Input.TexCoordinate) * Input.Color;
    
    // to avoid depth write
    if (color.a == 0.0) {
        discard;
    }
}
