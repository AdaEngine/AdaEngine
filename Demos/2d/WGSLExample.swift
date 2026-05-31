//
//  WGSLExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.12.2025.
//

#if canImport(WebGPU)
@_spi(Internal) import AdaEngine
import WebGPU

let isWGSLShader = false

@main
struct WGSLExampleApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(
                WGSLExamplePlugin()
            )
            .windowMode(.windowed)
            .windowTitle("WGSL Example")
    }
}

struct WGSLExamplePlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        // Spawn camera in main world
        app.main.spawn(bundle: Camera2D())

        let vert: Shader
        let frag: Shader
        if isWGSLShader {
            vert = Shader(source: triangleVertexShader, entryPoint: "vs_main", stage: .vertex)
            frag = Shader(source: triangleFragmentShader, entryPoint: "fs_main", stage: .fragment)

            try! vert.compile()
            try! frag.compile()
        } else {
            let vertexSource = try! ShaderSource(source: triangleVertexShaderGLSL, lang: .glsl)
        
            let fragmentSource = try! ShaderSource(source: triangleFragmentShaderGLSL, lang: .glsl)
        
            // Compile shaders using ShaderCompiler
            let vertexCompiler = ShaderCompiler(shaderSource: vertexSource)
            let fragmentCompiler = ShaderCompiler(shaderSource: fragmentSource)
        
            vert = try! vertexCompiler.compileShader(for: .vertex)
            frag = try! fragmentCompiler.compileShader(for: .fragment)
        }

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        renderWorld.insertResource(Shaders(vertex: vert, fragment: frag))

        // Remove default render system and add our custom WGPU render system
        renderWorld
            .removeSystem(RenderSystem.self, on: .render)
            .addSystem(WGPURenderSystemSystem.self, on: .render)
    }
}

struct Shaders: Resource {
    var vertex: Shader
    var fragment: Shader
}

@System
func WGPURenderSystem(
    _ targets: Query<Entity, Ref<RenderViewTarget>>,
    _ windows: ResMut<WindowSurfaces>,
    _ shaders: Res<Shaders>,
    _ renderDevice: Res<RenderDeviceHandler>
) {
    guard let device = (renderDevice.renderDevice as? WebGPURenderDevice)?.context.device else {
        return
    }

    targets.forEach { entity, renderTarget in
        // Get primary window drawable
        guard let primarySurface = windows.windows[.primary],
              let drawable = primarySurface.currentDrawable,
              let wgpuTexture = drawable.texture as? WGPUGPUTexture else {
            return
        }

        let textureView = wgpuTexture.textureView
        let textureFormat = wgpuTexture.texture.format

        let vertexShaderModule = (shaders.vertex.compiledShader as! WGPUShader).shader
        let fragmentShaderModule = (shaders.fragment.compiledShader as! WGPUShader).shader

        // Create pipeline layout
        let pipelineLayout = device.createPipelineLayout(
            descriptor: GPUPipelineLayoutDescriptor(bindGroupLayouts: [])
        )

        // Create render pipeline
        let pipeline = device.createRenderPipeline(
            descriptor: WebGPU.GPURenderPipelineDescriptor(
                label: "triangle_pipeline",
                layout: pipelineLayout,
                vertex: GPUVertexState(
                    module: vertexShaderModule,
                    entryPoint: "vs_main",
                    buffers: []
                ),
                primitive: GPUPrimitiveState(
                    topology: .triangleList,
                    stripIndexFormat: .undefined,
                    frontFace: .CCW,
                    cullMode: .none
                ),
                depthStencil: nil,
                multisample: GPUMultisampleState(
                    count: 1,
                    mask: UInt32.max,
                    alphaToCoverageEnabled: false
                ),
                fragment: GPUFragmentState(
                    module: fragmentShaderModule,
                    entryPoint: "fs_main",
                    constants: [:],
                    targets: [
                        GPUColorTargetState(
                            format: textureFormat,
                            blend: GPUBlendState(
                                color: GPUBlendComponent(
                                    operation: .add,
                                    srcFactor: .one,
                                    dstFactor: .zero
                                ),
                                alpha: GPUBlendComponent(
                                    operation: .add,
                                    srcFactor: .one,
                                    dstFactor: .zero
                                )
                            ),
                            writeMask: .all
                        )
                    ]
                )
            )
        )

        // Create command encoder and render pass
        let commandEncoder = device.createCommandEncoder()
        let renderPass = commandEncoder.beginRenderPass(
            descriptor: WebGPU.GPURenderPassDescriptor(
                colorAttachments: [
                    WebGPU.GPURenderPassColorAttachment(
                        view: textureView,
                        loadOp: .clear,
                        storeOp: .store,
                        clearValue: WebGPU.GPUColor(r: 0.1, g: 0.2, b: 0.3, a: 1.0)
                    )
                ]
            )
        )

        // Draw triangle
        renderPass.setPipeline(pipeline: pipeline)
        renderPass.draw(vertexCount: 3, instanceCount: 1, firstVertex: 0, firstInstance: 0)
        renderPass.end()

        // Submit commands
        let commandBuffer = commandEncoder.finish()
        device.queue.submit(commands: [commandBuffer])
    }

    // Present windows (drawable should be from the updated surface)
    for (_, window) in windows.windows.values {
        try? window.currentDrawable?.present()
    }
}

// WGSL vertex shader - outputs triangle positions directly
let triangleVertexShader = """
@vertex
fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> @builtin(position) vec4<f32> {
    var positions = array<vec2<f32>, 3>(
        vec2<f32>( 0.0,  0.5),   // top
        vec2<f32>(-0.5, -0.5),   // bottom left
        vec2<f32>( 0.5, -0.5)    // bottom right
    );
    return vec4<f32>(positions[vertexIndex], 0.0, 1.0);
}
"""

// WGSL fragment shader - outputs solid red color
let triangleFragmentShader = """
@fragment
fn fs_main() -> @location(0) vec4<f32> {
    return vec4<f32>(1.0, 0.0, 0.0, 1.0);
}
"""


// GLSL vertex shader - outputs triangle positions directly
// Note: GLSL uses different syntax than WGSL
let triangleVertexShaderGLSL = """
#version 450
#pragma stage : vert

[[main]]
void vs_main() {
    vec2 positions[3] = vec2[](
        vec2( 0.0,  0.5),   // top
        vec2(-0.5, -0.5),   // bottom left
        vec2( 0.5, -0.5)    // bottom right
    );
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
}
"""

// GLSL fragment shader - outputs solid red color
let triangleFragmentShaderGLSL = """
#version 450
#pragma stage : frag

layout(location = 0) out vec4 fragColor;

[[main]]
void fs_main() {
    fragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
"""

#else
@_spi(Internal) import AdaEngine

@main
struct WGSLExampleApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .windowMode(.windowed)
            .windowTitle("WGSL Example")
    }
}
#endif
