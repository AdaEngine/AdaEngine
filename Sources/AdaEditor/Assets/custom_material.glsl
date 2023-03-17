#version 450 core
#pragma stage : frag

#include <AdaEngine/Material2d.glsl>

struct CustomMaterial
{
    float Time;
};

[[main]]
void vertex()
{
//    float fade = 0.01;
//    float dist = sqrt(dot(Input.LocalPosition, Input.LocalPosition));
//    if (dist > 1.0 || dist < 1.0 - Input.Thickness - fade)
//        discard;
//
//    float alpha = 1.0 - smoothstep(1.0f - fade, 1.0f, dist);
//    alpha *= smoothstep(1.0 - Input.Thickness - fade, 1.0 - Input.Thickness, dist);
//    color = Input.Color;
//    color.a = alpha;
}

[[fragment]]
void fragment() {
    
}
