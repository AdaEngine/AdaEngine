//
//  WGSLExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.12.2025.
//

@_spi(Internal) import AdaEngine

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
        app.spawn(bundle: Camera2D())

        let vert = Shader(source: vertexShader, entryPoint: "vert", stage: .vertex)
        let frag = Shader(source: fragmentShader, entryPoint: "frag", stage: .fragment)
        try! vert.compile()
        try! frag.compile()

        let renderWorld = app.getSubworldBuilder(by: .renderWorld)!
        renderWorld.insertResource(Shaders(vertex: vert, fragment: frag))
        renderWorld.removeSystem(RenderSystem.self, on: .render)
        renderWorld.addSystem(WGPURenderSystemSystem.self, on: .render)
    }
}

struct Shaders: Resource {
    let vertex: Shader
    let fragment: Shader
}

@System
func WGPURenderSystem(
    _ targets: Query<Ref<RenderViewTarget>>,
    _ shaders: Res<Shaders>,
    _ renderDevice: Res<RenderDeviceHandler>,
    _ windows: Res<WindowSurfaces>
) {

    let device = renderDevice.renderDevice
    let renderPipelineDescriptor = RenderPipelineDescriptor(vertex: shaders.vertex, fragment: shaders.fragment)
    let renderPipeline = try! device.createRenderPipeline(from: renderPipelineDescriptor)

    targets.forEach { renderTarget in
        let commandBuffer = device.createCommandQueue().makeCommandBuffer()
        let renderPass = RenderPassDescriptor(colorAttachments: [
            RenderPassColorAttachmentDescriptor(
                texture: renderTarget.mainTexture!,
                operation: OperationDescriptor(loadAction: .clear, storeAction: .store),
                clearColor: Color.black
            )
        ])
        let renderCommandEncoder = commandBuffer.beginRenderPass(renderPass)
        renderCommandEncoder.setRenderPipelineState(renderPipeline)
        renderCommandEncoder.draw(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
        renderCommandEncoder.endRenderPass()
        commandBuffer.commit()
    }

    for (_, window) in windows.windows.values {
        try! window.currentDrawable?.present()
    }
}

let vertexShader = """
@vertex
fn vert(@builtin(vertex_index) vertexIndex: u32) -> @builtin(position) vec4<f32> {
    return vec4<f32>(0.0, 0.0, 0.0, 1.0);
}
"""

let fragmentShader = """
@fragment
fn frag() -> @location(0) vec4<f32> {
    return vec4<f32>(1.0, 0.0, 0.0, 1.0);
}
"""