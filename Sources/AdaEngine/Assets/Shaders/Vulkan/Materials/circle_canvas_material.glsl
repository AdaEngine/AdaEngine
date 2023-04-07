#version 450 core
#pragma stage : frag

#include <AdaEngine/CanvasMaterial.frag>

layout (std140, binding = 0) uniform CircleCanvasMaterial {
    float u_Fade;
    float u_Thickness;
    vec4 u_Color;
};

[[main]]
void circle_canvas_mesh_fragment()
{
    float fade = u_Fade;
    float thickness = u_Thickness;
    
    vec2 uv = Input.UV - 0.5;
    
    float dist = sqrt(dot(uv * 2, uv * 2)); // looks like we should pass local position)))
    if (dist > 1.0 || dist < 1.0 - thickness - fade)
        discard;

    float alpha = 1.0 - smoothstep(1.0f - fade, 1.0f, dist);
    alpha *= smoothstep(1.0 - thickness - fade, 1.0 - thickness, dist);
    COLOR = u_Color;
    COLOR.a = alpha;
}

