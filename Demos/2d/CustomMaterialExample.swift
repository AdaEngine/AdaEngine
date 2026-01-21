//
//  CustomMaterialApp.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 09.12.2025.
//

import AdaEngine

@main
struct CustomMaterialApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(
                CustomMaterialPlugin()
            )
            .windowMode(.windowed)
            .preferredRenderBackend(.metal)
    }
}

struct CustomMaterialPlugin: Plugin {
    func setup(in app: borrowing AdaApp.AppWorlds) {
        app.spawn(bundle: Camera2D())
        app.addSystem(UpdateMaterialSystem.self)
        app.addSystem(SetupSystem.self, on: .startup)
    }
}

@System
func Setup(
    _ device: Res<RenderDeviceHandler>,
    _ commands: Commands
) async {
    let texture = try! await AssetsManager.load(Texture2D.self, at: "Resources/dog.png", from: .module)
    commands.spawn {
        Mesh2D(mesh: .generate(from: Quad(size: .one), renderDevice: device.renderDevice), materials: [
            CustomMaterial(MyMaterial(color: .blue, customTexture: texture.asset))
        ])
    }
}

struct MyMaterial: CanvasMaterial {

    @Uniform(binding: 2, propertyName: "u_Time")
    var time: Float

    @Uniform(binding: 2, propertyName: "u_Color")
    var color: Color

    @FragmentTexture(binding: 0)
    var customTexture: Texture2D

    init(color: Color, customTexture: Texture2D) {
        self.time = 0
        self.color = color
        self.customTexture = customTexture
    }

    static func fragmentShader() throws -> AssetHandle<ShaderSource> {
        try AssetsManager.loadSync(
            ShaderSource.self,
            at: "Resources/custom_material.glsl",
            from: .module
        )
    }
}

@System
func UpdateMaterial(
    _ meshes: Query<Entity, Mesh2D>,
    _ input: Res<Input>,
    _ delta: Res<DeltaTime>
) {
    meshes.forEach { ent, mesh in
        if input.wrappedValue.isMouseButtonPressed(.left) {
            (mesh.materials[0] as? CustomMaterial<MyMaterial>)?.color = .mint
        } else {
            (mesh.materials[0] as? CustomMaterial<MyMaterial>)?.color = .pink
        }

        (mesh.materials[0] as? CustomMaterial<MyMaterial>)?.time += delta.deltaTime
    }
}
