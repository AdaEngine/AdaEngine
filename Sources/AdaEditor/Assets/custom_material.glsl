#version 450 core
#pragma stage : frag

#include <AdaEngine/CanvasMaterial.frag>

layout (std140, binding = 2) uniform CustomMaterial {
    vec4 u_Color;
    float u_Time;
};

[[main]]
void my_material_fragment()
{
    COLOR = vec4(1.0, 0.1, 1.0, 1.0);
}
