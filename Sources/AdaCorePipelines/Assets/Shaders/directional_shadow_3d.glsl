#version 450 core
#pragma stage : vert

layout (location = 0) in vec3 a_Position;
layout (location = 5) in vec4 a_Model0;
layout (location = 6) in vec4 a_Model1;
layout (location = 7) in vec4 a_Model2;
layout (location = 8) in vec4 a_Model3;

layout (binding = 2) uniform DirectionalShadowViewUniform {
    mat4 u_ShadowViewProjection;
};

[[main]]
void directional_shadow_3d_vertex()
{
    mat4 model = mat4(a_Model0, a_Model1, a_Model2, a_Model3);
    gl_Position = u_ShadowViewProjection * model * vec4(a_Position, 1.0);
}

#version 450 core
#pragma stage : frag

layout (location = 0) out vec4 o_Depth;

[[main]]
void directional_shadow_3d_fragment()
{
    o_Depth = vec4(gl_FragCoord.z);
}
