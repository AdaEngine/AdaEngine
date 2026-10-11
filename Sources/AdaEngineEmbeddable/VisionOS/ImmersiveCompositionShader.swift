/// Compositor shader compiled by both the immersive host and native GPU regression tests.
enum ImmersiveCompositionShader {
    static let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct VertexOut { float4 position [[position]]; float2 uv; uint layer [[render_target_array_index]]; };
        vertex VertexOut immersiveVertex(uint id [[vertex_id]], constant uint &layer [[buffer(0)]]) {
            float2 uv = float2((id << 1) & 2, id & 2);
            return { float4(uv * float2(2, -2) + float2(-1, 1), 0, 1), uv, layer };
        }
        struct FragmentOut { float4 color [[color(0)]]; float depth [[depth(any)]]; };
        fragment FragmentOut immersiveFragment(VertexOut in [[stage_in]],
            texture2d<float> color [[texture(0)]], depth2d<float> depth [[texture(1)]], constant uint &passthrough [[buffer(0)]]) {
            constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);
            constexpr sampler nearestSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
            // The 3D composite writes display-encoded sRGB into BGRA8. Decode before
            // writing to the compositor's sRGB attachment, which encodes once.
            float4 displayColor = color.sample(linearSampler, in.uv);
            float3 linearColor = select(displayColor.rgb / 12.92,
                pow((displayColor.rgb + 0.055) / 1.055, float3(2.4)), displayColor.rgb > 0.04045);
            float forwardDepth = depth.sample(nearestSampler, in.uv);
            // The scene composite can make a background pixel opaque. Its untouched
            // forward-depth clear value still identifies it as passthrough in mixed mode.
            if (passthrough != 0 && forwardDepth >= 1.0) { return { float4(0.0), 0.0 }; }
            float alpha = clamp(displayColor.a, 0.0, 1.0);
            // Compositor Services consumes premultiplied color and reverse depth.
            // A full-mode sky must have a valid far depth rather than the compositor's
            // empty-depth sentinel; mixed mode already discarded this background above.
            float reverseDepth = passthrough == 0 && forwardDepth >= 1.0 ? 0.00001 : 1.0 - forwardDepth;
            return { float4(linearColor * alpha, alpha), alpha > 0.0 ? reverseDepth : 0.0 };
        }
        """
}
