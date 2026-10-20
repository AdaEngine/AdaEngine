
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
void sprite_vertex()
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
layout (binding = 1) uniform sampler   u_Sampler;

#define ADA_GRAPH_SOURCE_MARKER 1

[[main]]
void sprite_fragment()
{
    #ifdef ADA_SHADER_GRAPH
    AdaGraphSurface surface = ada_graph_evaluate(Input.TexCoordinate);
    color = surface.color * Input.Color;
    color.a *= surface.alpha;
    if (ada_graph_values[0].z < 0.5) { color.a = 1.0; }
    else if (ada_graph_values[0].z < 1.5) {
        if (color.a < ada_graph_values[0].y) { discard; }
        color.a = 1.0;
    }
    #else
    color = texture(sampler2D(u_Texture, u_Sampler), Input.TexCoordinate) * Input.Color;
    #endif

    // to avoid depth write
    if (color.a == 0.0) {
        discard;
    }
}
