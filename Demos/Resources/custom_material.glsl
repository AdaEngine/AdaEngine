#version 450 core
#pragma stage : frag

#include <AdaEngine/CanvasMaterial.frag>

layout (binding = 0) uniform CustomMaterial {
    vec4 u_Color;
    float u_Time;
} customMaterial;

layout (set = 1, binding = 0) uniform texture2D customTexture;
layout (set = 1, binding = 1) uniform sampler u_Sampler;

[[main]]
void my_material_fragment()
{
    COLOR = texture(sampler2D(customTexture, u_Sampler), Input.UV) * customMaterial.u_Color;
    COLOR.b = sin(customMaterial.u_Time);
}
