#version 450 core
#pragma stage : vert

#include "Common.glsl"

layout (location = 0) in vec4 a_Position;
layout (location = 1) in vec4 a_Color;
layout (location = 2) in vec2 a_TexCoordinate;
layout (location = 3) in int a_TexIndex;

struct VertexOut
{
    vec4 Color;
    vec2 TexCoordinate;
};

layout (location = 3) out int TexIndex;
layout (location = 0) out VertexOut Output;

void main()
{
    Output.Color = a_Color;
    Output.TexCoordinate = a_TexCoordinate;
    TexIndex = a_TexIndex;
    
    gl_Position = u_ViewTransform * a_Position;
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
layout (location = 3) in flat int TexIndex;
layout (binding = 0) uniform sampler2D u_Textures[16];

void main()
{
    color = texture(u_Textures[TexIndex], Input.TexCoordinate) * Input.Color;
    
    // to avoid depth write
    if (color.a == 0.0) {
        discard;
    }
}

