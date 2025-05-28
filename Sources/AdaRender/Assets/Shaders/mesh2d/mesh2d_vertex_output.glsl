struct VertexOut
{
#ifdef VERTEX_POSITIONS
    vec4 WorldPosition;
#endif
    
#ifdef VERTEX_NORMALS
    vec3 WorldNormal;
#endif
#ifdef VERTEX_UVS
    vec2 UV;
#endif
#ifdef VERTEX_COLORS
    vec4 VertexColor;
#endif
};

layout (location = 0) in VertexOut Input;
layout (location = 0) out vec4 COLOR;
