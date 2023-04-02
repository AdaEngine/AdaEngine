#version 450 core
#pragma stage : frag

#include <AdaEngine/CanvasMaterial.frag>

layout (std140, binding = 2) uniform CustomMaterial {
    vec4 u_Color;
};

[[main]]
void my_material_fragment()
{
    COLOR = u_Color;
}
