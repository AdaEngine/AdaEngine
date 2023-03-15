#version 430 core
#pragma stage : vert

layout (location = 0) in vec4 a_Position;
layout (location = 1) in vec4 a_ForegroundColor;
layout (location = 2) in vec4 a_OutlineColor;
layout (location = 3) in vec2 a_TexCoordinate;
layout (location = 4) in vec2 a_TexSize;
layout (location = 5) in int a_TexIndex;

layout (std140, binding = 1) uniform Camera
{
    mat4 u_ViewTransform;
};

struct VertexOut
{
    vec4 ForegroundColor;
    vec4 OutlineColor;
    vec2 TexCoordinate;
    vec2 TexSize;
};

layout (location = 5) out int TexIndex;
layout (location = 0) out VertexOut Output;

void main() {
    Output.ForegroundColor = a_ForegroundColor;
    Output.OutlineColor = a_OutlineColor;
    Output.TexCoordinate = a_TexCoordinate;
    Output.TexSize = a_TexSize;
    TexIndex = a_TexIndex;

    gl_Position = u_ViewTransform * a_Position;
}

#version 450 core
#pragma stage : frag

layout (location = 0) out vec4 color;

struct VertexOut
{
    vec4 ForegroundColor;
    vec4 OutlineColor;
    vec2 TexCoordinate;
    vec2 TexSize;
};

layout (location = 0) in VertexOut Input;
layout (location = 5) in flat int TexIndex;
layout (binding = 0) uniform sampler2D u_FontAtlases[16];

float ScreenPxRange() {
    float pxRange = 2.0f;
    vec2 unitRange = vec2(pxRange) / vec2(textureSize(u_FontAtlases[TexIndex], 0));
    vec2 screenTexSize = vec2(1.0) / fwidth(Input.TexCoordinate);
    return max(0.5 * dot(unitRange, screenTexSize), 1.0);
}

float Median(vec3 msd) {
    return max(min(msd.r, msd.g), min(max(msd.r, msd.g), msd.b));
}

void main() {
    vec4 bgColor = vec4(Input.OutlineColor.rgb, 0.0);
    vec4 fgColor = Input.ForegroundColor;

    vec3 msd = texture(u_FontAtlases[TexIndex], Input.TexCoordinate).rgb;
    float sd = Median(msd);
    float px_Distance = ScreenPxRange() * (sd - 0.5f);
    float opacity = clamp(px_Distance + 0.5, 0.0, 1.0);

    color = mix(bgColor, fgColor, vec4(opacity));
}
