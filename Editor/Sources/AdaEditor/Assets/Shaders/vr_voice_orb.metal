#include <metal_stdlib>
using namespace metal;

// The Companion palette and flowing ribbons evaluated in sphere-local XYZ.
// Equirectangular UVs only choose a direction: noise stays continuous at the seam and poles.
float orbHash(float3 p) {
    p = fract(p * .3183099 + float3(.17, .31, .53));
    p *= 17.;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float orbNoise(float3 p) {
    float3 i = floor(p), f = fract(p);
    f = f * f * (3. - 2. * f);
    return mix(mix(mix(orbHash(i), orbHash(i + float3(1,0,0)), f.x),
                   mix(orbHash(i + float3(0,1,0)), orbHash(i + float3(1,1,0)), f.x), f.y),
               mix(mix(orbHash(i + float3(0,0,1)), orbHash(i + float3(1,0,1)), f.x),
                   mix(orbHash(i + float3(0,1,1)), orbHash(i + float3(1,1,1)), f.x), f.y), f.z);
}
float2 orbRotate(float2 p, float a) {
    float c = cos(a), s = sin(a);
    return float2(c * p.x + s * p.y, -s * p.x + c * p.y);
}
kernel void vrVoiceOrb(texture2d<float, access::write> output [[texture(0)]],
                       constant float2 &parameters [[buffer(0)]], uint2 pixel [[thread_position_in_grid]]) {
    if (pixel.x >= output.get_width() || pixel.y >= output.get_height()) return;
    float2 uv = (float2(pixel) + .5) / float2(output.get_width(), output.get_height());
    float longitude = uv.x * 2. * M_PI_F, latitude = uv.y * M_PI_F;
    float3 direction = float3(sin(latitude) * cos(longitude), cos(latitude), sin(latitude) * sin(longitude));
    float t = parameters.x * .23, level = parameters.y;
    float3 light = float3(.055, .12, .30);
    // Integrate the same soft ribbon field radially so every side has its own luminous detail.
    for (int i = 0; i < 12; ++i) {
        float3 p = direction * (.25 + .75 * (float(i) + .5) / 12.);
        p.xz = orbRotate(p.xz, t * .37);
        p.xy = orbRotate(p.xy, t * .20);
        float n = orbNoise(p * 2.9 + float3(t * .55, -t * .38, t * .25));
        float n2 = orbNoise(p * 5.6 - float3(t * .2, t * .45, 0.));
        // A Cartesian field avoids atan's discontinuity in color and at the poles.
        float flow = p.x * 5. + p.y * 3.2 + p.z * 4.5 - t * 1.35 + (n - .5) * 4.2;
        float ribbon = pow(.5 + .5 * sin(flow), 5.);
        float secondary = pow(.5 + .5 * sin(p.y * 6. - p.z * 4.5 - t * .8 + n2 * 3.), 9.);
        float hue = .5 + .5 * sin(flow * .45 + p.z * 2. + t * .7 + n * 3.);
        float3 color = mix(float3(.055,.25,.96), float3(.16,.88,1.02), smoothstep(.15,.76,hue));
        color = mix(color, float3(.87,.77,.96), pow(.5 + .5 * sin(p.y * 3. + p.z * 2. + t * .9 + n2 * 2.), 6.) * .75);
        color = mix(color, float3(.58,.38,1.), level * .23);
        float density = (ribbon * .92 + secondary * .32 + .08) * (.22 + .78 * n);
        light += color * density * .12 * (1. + level * 1.3);
    }
    light *= .68 + .32 * (.5 + .5 * direction.y);
    output.write(float4(1. - exp(-light * 2.7), 1.), pixel);
}
