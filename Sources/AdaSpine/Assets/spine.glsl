#version 450 core
#pragma stage : vert

#include <AdaEngine/View.glsl>

layout(location = 0) in vec4 a_Position;
layout(location = 1) in vec4 a_Color;
layout(location = 2) in vec2 a_TexCoordinate;
layout(location = 3) in vec4 a_DarkColor;

layout(location = 0) out vec4 lightColor;
layout(location = 1) out vec2 textureCoordinate;
layout(location = 2) out vec4 darkColor;

[[main]]
void spine_vertex() {
    lightColor = a_Color;
    textureCoordinate = a_TexCoordinate;
    darkColor = a_DarkColor;
    gl_Position = u_ViewProjection * a_Position;
}

#version 450 core
#pragma stage : frag

layout(location = 0) in vec4 lightColor;
layout(location = 1) in vec2 textureCoordinate;
layout(location = 2) in vec4 darkColor;
layout(binding = 0) uniform texture2D u_Texture;
layout(binding = 1) uniform sampler u_Sampler;
layout(location = 0) out vec4 outputColor;

[[main]]
void spine_fragment() {
    vec4 texel = texture(sampler2D(u_Texture, u_Sampler), textureCoordinate);
    // PMA textures use their alpha as the upper bound for the dark contribution.
    vec3 darkWeight = vec3(mix(1.0, texel.a, darkColor.a)) - texel.rgb;
    outputColor = vec4(texel.rgb * lightColor.rgb + darkWeight * darkColor.rgb, texel.a * lightColor.a);
    if (outputColor.a == 0.0) discard;
}
