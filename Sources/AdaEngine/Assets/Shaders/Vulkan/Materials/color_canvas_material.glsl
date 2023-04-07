#version 450 core
#pragma stage : frag

#include <AdaEngine/CanvasMaterial.frag>

layout (std140, binding = 0) uniform ColorCanvasMaterial {
    vec4 u_Color;
};

[[main]]
void color_canvas_mesh_fragment()
{
    COLOR = u_Color;
}
