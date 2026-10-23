// FSR 1 EASU/RCAS ported to WGSL from AMD's ffx_fsr1.h (v1.20210629).
// https://github.com/GPUOpen-Effects/FidelityFX-FSR/blob/master/ffx-fsr/ffx_fsr1.h
// Uses full precision arithmetic and clamped texture loads instead of gather callbacks.

//
// Copyright (c) 2021 Advanced Micro Devices, Inc. All rights reserved.
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#if WEBGPU_ENABLED && canImport(WebGPU)
    enum WGPUFSRShaders {
        static let common = """
            @group(0) @binding(0) var source: texture_2d<f32>;
            @group(0) @binding(1) var<uniform> scale: vec4f;

            @vertex fn vertex(@builtin(vertex_index) index: u32) -> @builtin(position) vec4f {
                let p = array<vec2f, 3>(vec2f(-1, -1), vec2f(3, -1), vec2f(-1, 3));
                return vec4f(p[index], 0, 1);
            }
            fn load(p: vec2i) -> vec4f {
                return textureLoad(source, clamp(p, vec2i(0), vec2i(textureDimensions(source)) - 1), 0);
            }
            fn luma(c: vec3f) -> f32 { return c.g + 0.5 * (c.r + c.b); }
            """

        static let easu = common + """
            // Returns weighted gradient direction in xy and edge length in z.
            fn edge(w: f32, a: f32, b: f32, c: f32, d: f32, e: f32) -> vec3f {
                let direction = vec2f(d - b, e - a);
                let magnitude = max(abs(vec2f(d - c, e - c)), abs(vec2f(c - b, c - a)));
                let length = clamp(abs(direction) / max(magnitude, vec2f(1e-8)), vec2f(0), vec2f(1));
                return vec3f(direction, dot(length, length)) * w;
            }
            fn weight(offset: vec2f, direction: vec2f, length: vec2f, lobe: f32) -> f32 {
                let v = vec2f(dot(offset, direction), dot(offset, vec2f(-direction.y, direction.x))) * length;
                let distance = min(dot(v, v), 1.0 / lobe);
                let base = 0.4 * distance - 1.0;
                let window = lobe * distance - 1.0;
                return (1.5625 * base * base - 0.5625) * window * window;
            }
            @fragment fn fragment(@builtin(position) position: vec4f) -> @location(0) vec4f {
                // Pixel centers map to input texel centers, matching FsrEasuCon.
                let mapped = position.xy * scale.xy - 0.5;
                let origin = vec2i(floor(mapped));
                let pp = fract(mapped);
                let b = load(origin + vec2i(0, -1)).rgb;
                let c = load(origin + vec2i(1, -1)).rgb;
                let e = load(origin + vec2i(-1, 0)).rgb;
                let f = load(origin);
                let g = load(origin + vec2i(1, 0));
                let h = load(origin + vec2i(2, 0)).rgb;
                let i = load(origin + vec2i(-1, 1)).rgb;
                let j = load(origin + vec2i(0, 1));
                let k = load(origin + vec2i(1, 1));
                let l = load(origin + vec2i(2, 1)).rgb;
                let n = load(origin + vec2i(0, 2)).rgb;
                let o = load(origin + vec2i(1, 2)).rgb;
                let gradient =
                    edge((1.0-pp.x)*(1.0-pp.y), luma(b), luma(e), luma(f.rgb), luma(g.rgb), luma(j.rgb)) +
                    edge(pp.x*(1.0-pp.y), luma(c), luma(f.rgb), luma(g.rgb), luma(h), luma(k.rgb)) +
                    edge((1.0-pp.x)*pp.y, luma(f.rgb), luma(i), luma(j.rgb), luma(k.rgb), luma(n)) +
                    edge(pp.x*pp.y, luma(g.rgb), luma(j.rgb), luma(k.rgb), luma(l), luma(o));
                var direction = vec2f(1, 0);
                if (dot(gradient.xy, gradient.xy) >= 1.0 / 32768.0) { direction = normalize(gradient.xy); }
                let length = 0.25 * gradient.z * gradient.z;
                let stretch = dot(direction, direction) / max(abs(direction.x), abs(direction.y));
                let anisotropy = vec2f(1.0 + (stretch - 1.0) * length, 1.0 - 0.5 * length);
                let lobe = 0.5 - 0.29 * length;
                let offsets = array<vec2f, 12>(
                    vec2f(0,-1), vec2f(1,-1), vec2f(-1,1), vec2f(0,1), vec2f(0,0), vec2f(-1,0),
                    vec2f(1,1), vec2f(2,1), vec2f(2,0), vec2f(1,0), vec2f(1,2), vec2f(0,2));
                let colors = array<vec3f, 12>(b, c, i, j.rgb, f.rgb, e, k.rgb, l, h, g.rgb, o, n);
                var color = vec3f(0);
                var total = 0.0;
                for (var tap = 0u; tap < 12u; tap++) {
                    let w = weight(offsets[tap] - pp, direction, anisotropy, lobe);
                    color += colors[tap] * w;
                    total += w;
                }
                let minimum = min(min(f.rgb, g.rgb), min(j.rgb, k.rgb));
                let maximum = max(max(f.rgb, g.rgb), max(j.rgb, k.rgb));
                // FSR reconstructs RGB; interpolate alpha without ringing for embedded transparent views.
                let alpha = mix(mix(f.a, g.a, pp.x), mix(j.a, k.a, pp.x), pp.y);
                return vec4f(clamp(color / total, minimum, maximum), alpha);
            }
            """

        static let rcas = common + """
            @fragment fn fragment(@builtin(position) position: vec4f) -> @location(0) vec4f {
                let p = vec2i(position.xy);
                let b = load(p + vec2i(0, -1)).rgb;
                let d = load(p + vec2i(-1, 0)).rgb;
                let e = load(p);
                let f = load(p + vec2i(1, 0)).rgb;
                let h = load(p + vec2i(0, 1)).rgb;
                let minimum = min(min(b, d), min(f, h));
                let maximum = max(max(b, d), max(f, h));
                // Avoid 0/0 for constant black or white channels.
                let hitMin = min(minimum, e.rgb) / max(4.0 * maximum, vec3f(1e-8));
                let hitMax = (1.0 - max(maximum, e.rgb)) / min(4.0 * minimum - 4.0, vec3f(-1e-8));
                let lobes = max(-hitMin, hitMax);
                // FsrRcasCon(0.2): a small reduction from maximum sharpening.
                let lobe = clamp(max(max(lobes.r, lobes.g), lobes.b), -0.1875, 0.0) * exp2(-0.2);
                return vec4f((lobe * (b + d + f + h) + e.rgb) / (4.0 * lobe + 1.0), e.a);
            }
            """
    }
#endif
