#version 450 core
#pragma stage : frag

#include <AdaEngine/CanvasMaterial.frag>

layout (binding = 0) uniform CustomMaterial {
    float u_Time;
    vec4 u_Color;
};

layout (binding = 0) uniform sampler2D customTexture;

[[main]]
void my_material_fragment()
{
    COLOR = texture(customTexture, Input.UV) * u_Color;
    COLOR.b = sin(u_Time);
}
