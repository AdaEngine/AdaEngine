//
//  CustomMaterialApp.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 09.12.2025.
//

import AdaEngine
import Foundation

private enum CustomMaterialShaderError: LocalizedError {
    case missingResourceURL

    var errorDescription: String? {
        switch self {
        case .missingResourceURL:
            return "Custom material shader resource bundle is missing."
        }
    }
}

private func loadCustomMaterialShaderSource(
    at path: String,
    from bundle: Bundle
) throws -> AssetHandle<ShaderSource> {
    guard let resourceURL = bundle.resourceURL else {
        throw CustomMaterialShaderError.missingResourceURL
    }

    let resourcePath = path.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? path
    return AssetHandle(try ShaderSource(from: resourceURL.appendingPathComponent(resourcePath)))
}

@main
struct CustomMaterialApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(
                CustomMaterialPlugin()
            )
            .windowMode(.windowed)
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
        Mesh2D(mesh: .generate(from: Quad(size: Vector2.init(200, 200)), renderDevice: device.renderDevice), materials: [
            CustomMaterial(MyMaterial(color: .blue, customTexture: texture.asset))
        ])
        Transform()
    }
}

struct MyMaterial: CanvasMaterial {

    struct CustomMaterialUniform {
        var color: Color
        var time: Float
    }

    @Uniform
    var customMaterial: CustomMaterialUniform

    @FragmentTexture(samplerName: "u_Sampler")
    var customTexture: Texture2D

    init(color: Color, customTexture: Texture2D) {
        self.customMaterial = CustomMaterialUniform(color: color, time: 0)
        self.customTexture = customTexture
    }

    static func vertexShader() throws -> AssetHandle<ShaderSource> {
        try loadCustomMaterialShaderSource(
            at: "Resources/custom_material_vertex.glsl",
            from: .module
        )
    }

    static func fragmentShader() throws -> AssetHandle<ShaderSource> {
        try loadCustomMaterialShaderSource(
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
            (mesh.materials[0] as? CustomMaterial<MyMaterial>)?.customMaterial.color = .mint
        } else {
            (mesh.materials[0] as? CustomMaterial<MyMaterial>)?.customMaterial.color = .pink
        }

        (mesh.materials[0] as? CustomMaterial<MyMaterial>)?.customMaterial.time += delta.deltaTime
    }
}
