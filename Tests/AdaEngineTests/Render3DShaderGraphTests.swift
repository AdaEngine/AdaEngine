#if os(macOS)
@testable import AdaCorePipelines
import AdaRender
import AdaScene
import AdaTransform
import Foundation
import Testing

extension Render3DGPUTests {
    @MainActor
    @Suite("Shader Graph GPU rendering")
    struct ShaderGraphs {
        @Test(.enabled(if: GoldenFrame.activeBackend == .metal))
        func alphaMaskRunsThroughActualTemporalMotionRendering() async throws {
            let scene = try await DebugViews.makeScene(temporalRenderScale: 0.67)
            try #require(scene.device.supportsTemporalUpscaling)
            let entity = try #require(scene.sphereEntities.first)
            let material = try #require(entity.components[Mesh3DComponent.self]?.materials.first as? PBRMaterial)
            var graph = ShaderGraph(target: .pbrSurface, output: "output", nodes: [
                .init(id: "alpha", operation: .parameter, value: [1], reference: "alpha"),
                .init(id: "output", operation: .output, inputs: ["alpha": .init("alpha")])
            ])
            graph.renderSettings.mode = .mask
            let instance = try ShaderGraphMaterial(source: .init(graph: graph))
            material.graphMaterial = instance
            let visible = try await scene.render(.none, frames: 6)
            let world = try #require(scene.app.getSubworldBuilder(by: .renderWorld)?.main)
            let statistics = try #require(world.getResource(Render3DTemporalStatistics.self))
            #expect(statistics.snapshots.values.contains { $0.encodedFrames + $0.fallbackFrames > 0 && $0.inputWidth < $0.outputWidth })
            try instance.setValue([0], for: "alpha")
            let hidden = try await scene.render(.none, frames: 8)
            #expect(visible.data != hidden.data)
            #expect(instance.compilationError == nil)
        }

        @Test(.enabled(if: GoldenFrame.activeBackend != nil), arguments: [false, true])
        func animatedAlphaMaskMatchesRemovingGeometryAndItsShadows(localShadows: Bool) async throws {
            let scene = try await DebugViews.makeScene()
            if localShadows {
                scene.app.main.spawn("Graph test point light") {
                    PointLightComponent(intensity: 3, castShadows: true, range: 8)
                    Transform(position: [-2, 2, -2])
                }
            }
            let entity = try #require(scene.sphereEntities.first)
            let mesh = try #require(entity.components[Mesh3DComponent.self])
            let material = try #require(mesh.materials.first as? PBRMaterial)
            var graph = ShaderGraph(target: .pbrSurface, output: "output", nodes: [
                .init(id: "alpha", operation: .parameter, value: [1], reference: "alpha"),
                .init(id: "output", operation: .output, inputs: ["alpha": .init("alpha")])
            ])
            graph.renderSettings.mode = .mask
            let instance = try ShaderGraphMaterial(source: .init(graph: graph))
            material.graphMaterial = instance
            let visible = try await scene.render(.none)
            try instance.setValue([0], for: "alpha")
            let clipped = try await scene.render(.none)
            let clippedDepth = try await scene.render(.depth)
            #expect(visible.data != clipped.data)
            entity.components[Visibility.self] = .hidden
            let hidden = try await scene.render(.none)
            let hiddenDepth = try await scene.render(.depth)
            #expect(GoldenFrame.compare(clipped, hidden, tolerance: GoldenFrame.activeTolerance).passes(GoldenFrame.activeTolerance))
            #expect(clippedDepth.data == hiddenDepth.data)
            #expect(instance.compilationError == nil)
        }

        @Test(.enabled(if: GoldenFrame.activeBackend != nil))
        func pbrGraphValuesReachTheProductionGBuffer() async throws {
            let scene = try await DebugViews.makeScene()
            let material = try #require(scene.groundMaterial)
            let baseline = try await scene.render(.roughness)
            let x = baseline.width / 2, y = baseline.height - 30
            #expect(abs(baseline.getPixel(x: x, y: y).red - 0.9) < 0.06)
            let graph = ShaderGraph(target: .pbrSurface, output: "output", nodes: [
                .init(id: "roughness", operation: .parameter, value: [0.25], reference: "roughness"),
                .init(id: "image", operation: .parameter, type: .texture2D, reference: "image"),
                .init(id: "uv", operation: .uv, type: .vector2),
                .init(id: "sample", operation: .sampleTexture, type: .vector4, inputs: ["texture": .init("image"), "uv": .init("uv")]),
                .init(id: "output", operation: .output, inputs: ["roughness": .init("roughness"), "baseColor": .init("sample", port: "color")])
            ])
            let instance = try ShaderGraphMaterial(source: .init(graph: graph))
            material.graphMaterial = instance
            let first = try await scene.render(.roughness)
            #expect(abs(first.getPixel(x: x, y: y).red - 0.25) < 0.06)
            #expect(instance.compilationError == nil)
            try instance.setValue([0.72], for: "roughness")
            let second = try await scene.render(.roughness)
            #expect(abs(second.getPixel(x: x, y: y).red - 0.72) < 0.06)
            #expect(first.data != second.data)
            let root = ProcessInfo.processInfo.environment["ADAENGINE_SHADER_SOURCE_ROOT"].map { URL(fileURLWithPath: $0) }
                ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            try instance.setTexturePath(root.appendingPathComponent("Tests/AdaRenderTests/Fixtures/Images/red.jpg").path, for: "image")
            let textured = try await scene.render(.albedo)
            let pixel = textured.getPixel(x: x, y: y)
            #expect(pixel.red > pixel.green + 0.3)
            #expect(pixel.red > pixel.blue + 0.3)
            material.graphMaterial = nil
            let restored = try await scene.render(.roughness)
            #expect(restored.data == baseline.data)
        }
    }
}
#endif
