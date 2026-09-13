// Web Player UI material ABI 1. This file is loaded at runtime, never embedded in Swift.
@group(1) @binding(0) var<uniform> parameters: vec4<f32>;
@group(1) @binding(1) var image: texture_2d<f32>;
@group(1) @binding(2) var imageSampler: sampler;

@fragment
fn player_fragment(@location(0) uv: vec2<f32>) -> @location(0) vec4<f32> {
    let pixel = textureSample(image, imageSampler, uv);
    let inverted = vec3<f32>(1.0) - pixel.rgb;
    return vec4<f32>(mix(pixel.rgb, inverted, clamp(parameters.x, 0.0, 1.0)), pixel.a);
}
