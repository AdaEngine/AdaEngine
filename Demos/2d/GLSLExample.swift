//
//  GLSLExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.12.2025.
//

@_spi(Internal) import AdaEngine
import WebGPU

@main
struct GLSLExampleApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(
                GLSLExamplePlugin()
            )
            .windowMode(.windowed)
            .windowTitle("GLSL Example")
    }
}

struct GLSLExamplePlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        // Spawn camera in main world
        app.main.spawn(bundle: Camera2D())

        // Create GLSL shader sources
        let vertexSource = try! ShaderSource(source: triangleVertexShaderGLSL, lang: .glsl)
        vertexSource.setSource(triangleVertexShaderGLSL, for: .vertex)
        
        let fragmentSource = try! ShaderSource(source: triangleFragmentShaderGLSL, lang: .glsl)
        fragmentSource.setSource(triangleFragmentShaderGLSL, for: .fragment)
        
        // Compile shaders using ShaderCompiler
        let vertexCompiler = ShaderCompiler(shaderSource: vertexSource)
        let fragmentCompiler = ShaderCompiler(shaderSource: fragmentSource)
        
        let vert = try! vertexCompiler.compileShader(for: .vertex)
        let frag = try! fragmentCompiler.compileShader(for: .fragment)

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        renderWorld.insertResource(Shaders(vertex: vert, fragment: frag))

        // Initialize cached pipeline resource
        renderWorld.insertResource(CachedPipeline(pipeline: nil, format: nil))

        // Remove default render system and add our custom WGPU render system
        renderWorld
            .removeSystem(RenderSystem.self, on: .render)
            .addSystem(GLSLRenderSystemSystem.self, on: .render)
    }
}

struct Shaders: Resource {
    var vertex: Shader
    var fragment: Shader
}

// Cache for render pipeline to avoid recreating it every frame
struct CachedPipeline: Resource {
    var pipeline: WebGPU.RenderPipeline?
    var format: WebGPU.TextureFormat?
}

@System
func GLSLRenderSystem(
    _ targets: Query<Entity, Ref<RenderViewTarget>>,
    _ windows: ResMut<WindowSurfaces>,
    _ shaders: Res<Shaders>,
    _ renderDevice: Res<RenderDeviceHandler>,
    _ cachedPipeline: ResMut<CachedPipeline>
) {
    guard let device = (renderDevice.renderDevice as? WebGPURenderDevice)?.context.device else {
        return
    }

    // Update drawables for each window
    for (windowRef, windowSurface) in windows.windows.values {
        guard let swapchain = windowSurface.swapchain else {
            continue
        }
        windows.windows[windowRef]?.currentDrawable = swapchain.getNextDrawable(renderDevice.renderDevice)
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

        // Get or create cached pipeline
        var pipeline: WebGPU.RenderPipeline
        if let cached = cachedPipeline.pipeline, cachedPipeline.format == textureFormat {
            pipeline = cached
        } else {
            // Get compiled shader modules from GLSL-compiled shaders
            let vertexShaderModule = (shaders.vertex.compiledShader as! WGPUShader).shader
            let fragmentShaderModule = (shaders.fragment.compiledShader as! WGPUShader).shader

            // Create pipeline layout
            let pipelineLayout = device.createPipelineLayout(
                descriptor: PipelineLayoutDescriptor(bindGroupLayouts: [])
            )

            // Create render pipeline
            pipeline = device.createRenderPipeline(
                descriptor: WebGPU.RenderPipelineDescriptor(
                    label: "triangle_pipeline_glsl",
                    layout: pipelineLayout,
                    vertex: VertexState(
                        module: vertexShaderModule,
                        entryPoint: shaders.vertex.entryPoint,
                        constants: [],
                        buffers: []
                    ),
                    primitive: PrimitiveState(
                        topology: .triangleList,
                        stripIndexFormat: .undefined,
                        frontFace: .ccw,
                        cullMode: .none
                    ),
                    depthStencil: nil,
                    multisample: MultisampleState(
                        count: 1,
                        mask: ~0,
                        alphaToCoverageEnabled: false
                    ),
                    fragment: FragmentState(
                        module: fragmentShaderModule,
                        entryPoint: shaders.fragment.entryPoint,
                        constants: [],
                        targets: [
                            ColorTargetState(
                                format: textureFormat,
                                blend: BlendState(
                                    color: BlendComponent(
                                        operation: .add,
                                        srcFactor: .one,
                                        dstFactor: .zero
                                    ),
                                    alpha: BlendComponent(
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
            
            // Cache the pipeline
            cachedPipeline.pipeline = pipeline
            cachedPipeline.format = textureFormat
        }

        // Create command encoder and render pass
        let commandEncoder = device.createCommandEncoder()
        let renderPass = commandEncoder.beginRenderPass(
            descriptor: WebGPU.RenderPassDescriptor(
                colorAttachments: [
                    WebGPU.RenderPassColorAttachment(
                        view: textureView,
                        loadOp: .clear,
                        storeOp: .store,
                        clearValue: WebGPU.Color(r: 0.1, g: 0.2, b: 0.3, a: 1.0)
                    )
                ]
            )
        )

        // Draw triangle
        renderPass.setPipeline(pipeline)
        renderPass.draw(vertexCount: 3)
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

// GLSL vertex shader - outputs triangle positions directly
// Note: GLSL uses different syntax than WGSL
let triangleVertexShaderGLSL = """
#version 450
#pragma stage : vert

void main() {
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

void main() {
    fragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
"""

