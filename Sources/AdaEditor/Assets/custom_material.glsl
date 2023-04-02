#version 450 core
#pragma stage : frag

#include <AdaEngine/CanvasMaterial.frag>

layout (std140, binding = 2) uniform CustomMaterial {
    vec4 u_Color;
};

layout (binding = 0) uniform sampler2D customTexture;

[[main]]
void my_material_fragment()
{
    COLOR = texture(customTexture, Input.UV) * u_Color;
}
