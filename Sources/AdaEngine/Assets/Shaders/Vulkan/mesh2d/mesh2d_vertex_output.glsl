struct VertexOut
{
    vec4 WorldPosition;
    vec3 WorldNormal;
    vec2 UV;
    vec4 VertexColor;
};

layout (location = 0) in VertexOut Input;
