#version 450 core
#pragma stage : vert

#include <AdaEngine/View.glsl>


#ifdef VERTEX_POSITIONS
layout (location = 0) in vec3 a_Position;
#endif

#ifdef VERTEX_COLORS
layout (location = 1) in vec4 a_Color;
#endif

layout (location = 2) in vec2 a_TexCoordinate;

layout (location = 3) in int a_TexIndex;

struct VertexOut
{
    vec4 Color;
    vec2 TexCoordinate;
};

layout (location = 3) out int TexIndex;
layout (location = 0) out VertexOut Output;

[[main]]
void quad_vertex()
{
#ifdef VERTEX_COLORS
    Output.Color = a_Color;
#endif
    Output.TexCoordinate = a_TexCoordinate;
    TexIndex = a_TexIndex;
    
#ifdef VERTEX_POSITIONS
    gl_Position = u_ViewProjection * vec4(a_Position, 1.0);
#else
    gl_Position = u_ViewProjection * vec4(1.0, 1.0, 1.0, 1.0);
#endif
    
}

#version 450 core
#pragma stage : frag

layout (location = 0) out vec4 color;

layout (std140, binding = 2) uniform CustomMaterial {
    float u_Time;
    vec4 u_Color;
};

struct VertexOut
{
    vec4 Color;
    vec2 TexCoordinate;
};

layout (location = 0) in VertexOut Input;
layout (location = 3) in flat int TexIndex;
layout (binding = 0) uniform sampler2D u_Textures[16];

[[main]]
void quad_fragment()
{
#if VERTEX_COLORS
    color = u_Color;//texture(u_Textures[TexIndex], Input.TexCoordinate) * Input.Color;
    
    // to avoid depth write
    if (color.a == 0.0) {
        discard;
    }
#else
    color = vec4(1.0, 0.0, 1.0, 0.0);
#endif
}
