#if os(visionOS)
    import Foundation
    import Metal
    import RealityKit
    import SwiftUI

    /// A real sphere with a seamless animated material, including when the window is viewed edge-on.
    @available(visionOS 26.0, *)
    struct EditorVRVoiceOrb: SwiftUI.View {
        var activity: MobileVoiceOrbActivity
        var audioLevel: Float
        @SwiftUI.State private var renderer: EditorVRVoiceOrbRenderer?
        @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion
        @SwiftUI.Environment(\.scenePhase) private var scenePhase

        var body: some SwiftUI.View {
            SwiftUI.GeometryReader3D { geometry in
                RealityView { content in
                    do {
                        let renderer = try EditorVRVoiceOrbRenderer()
                        renderer.animation.activity = activity
                        renderer.animation.audioLevel = audioLevel
                        renderer.reduceMotion = reduceMotion
                        renderer.place(in: content.convert(geometry.frame(in: .local), from: .local, to: .scene))
                        content.add(renderer.entity)
                        self.renderer = renderer
                    } catch {
                        // Resource failures must still leave a spherical, visible control.
                        let sphere = ModelEntity(mesh: .generateSphere(radius: 1), materials: [UnlitMaterial(color: .cyan)])
                        let bounds = content.convert(geometry.frame(in: .local), from: .local, to: .scene)
                        sphere.scale = SIMD3(repeating: min(bounds.extents.x, bounds.extents.y) * 0.35)
                        content.add(sphere)
                        print("[AdaStudioVR] Voice sphere material failed: \(error)")
                    }
                } update: { content in
                    renderer?.animation.activity = activity
                    renderer?.animation.audioLevel = audioLevel
                    renderer?.reduceMotion = reduceMotion
                    renderer?.place(in: content.convert(geometry.frame(in: .local), from: .local, to: .scene))
                }
                .realityViewLayoutBehavior(.centered)
                .task(id: scenePhase) { @MainActor in
                    guard scenePhase == .active else {
                        return
                    }
                    let clock = ContinuousClock()
                    var previous = clock.now
                    while !Task.isCancelled {
                        let now = clock.now
                        let elapsed = previous.duration(to: now).components
                        previous = now
                        renderer?.advance(Float(elapsed.seconds) + Float(elapsed.attoseconds) / 1e18)
                        do {
                            try await Task.sleep(for: .milliseconds(33))
                        } catch { return }
                    }
                }
            }
            .frame(width: 180, height: 180)
            .frame(depth: 180)
        }
    }

    @available(visionOS 26.0, *)
    @MainActor
    private final class EditorVRVoiceOrbRenderer {
        let entity: ModelEntity
        var animation = MobileVoiceOrbAnimation()
        var reduceMotion = false
        private let texture: LowLevelTexture
        private let pipeline: any MTLComputePipelineState
        private let queue: any MTLCommandQueue
        private var pending: (any MTLCommandBuffer)?
        private var radius: Float = 0.06

        init() throws {
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
                let url = Bundle.editor.url(forResource: "vr_voice_orb", withExtension: "metal", subdirectory: "Assets/Shaders")
            else { throw CocoaError(.fileNoSuchFile) }
            let library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
            guard let function = library.makeFunction(name: "vrVoiceOrb") else { throw CocoaError(.coderInvalidValue) }
            pipeline = try device.makeComputePipelineState(function: function)
            self.queue = queue
            texture = try LowLevelTexture(descriptor: .init(
                pixelFormat: .rgba8Unorm, width: 512, height: 256, textureUsage: [.shaderRead, .shaderWrite]
            ))
            var material = UnlitMaterial(applyPostProcessToneMap: false)
            material.color = .init(texture: .init(try TextureResource(from: texture)))
            entity = ModelEntity(mesh: .generateSphere(radius: 1), materials: [material])
            entity.name = "Ada Voice Sphere"
            // Concentric translucent shells give the glow depth from every viewing angle.
            let mesh = entity.model?.mesh ?? .generateSphere(radius: 1)
            for (scale, opacity) in [(Float(1.06), Float(0.045)), (1.13, 0.025), (1.21, 0.012)] {
                var glow = UnlitMaterial(color: .init(red: 0.25, green: 0.5, blue: 1, alpha: 1))
                glow.blending = .transparent(opacity: .init(floatLiteral: opacity))
                glow.writesDepth = false
                let shell = ModelEntity(mesh: mesh, materials: [glow])
                shell.scale = SIMD3(repeating: scale)
                entity.addChild(shell)
            }
            render()
            #if DEBUG
                print("[AdaStudioVR] Voice sphere ready; XYZ bounds=\(entity.visualBounds(relativeTo: entity).extents)")
            #endif
        }

        func place(in bounds: BoundingBox) {
            radius = min(bounds.extents.x, bounds.extents.y) * 0.35
            updateScale()
        }

        func advance(_ deltaTime: Float) {
            guard animation.advance(deltaTime, reduceMotion: reduceMotion) else {
                return
            }
            updateScale()
            render()
        }

        private func updateScale() {
            let breath = 1 + 0.025 * sin(animation.time * 0.8) + animation.level * 0.15
            // Equal XYZ scale preserves the sphere through breathing and audio pulses.
            entity.scale = SIMD3(repeating: radius * breath)
        }

        private func render() {
            // Keep at most one update in flight; no CPU waits or unbounded GPU submission.
            if let pending, pending.status != .completed, pending.status != .error {
                return
            }
            guard let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder() else {
                return
            }
            var parameters = SIMD2(animation.time, animation.level)
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(texture.replace(using: command), index: 0)
            unsafe encoder.setBytes(&parameters, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
            encoder.dispatchThreadgroups(
                MTLSize(width: 32, height: 16, depth: 1),
                threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1)
            )
            encoder.endEncoding()
            command.commit()
            pending = command
        }
    }
#endif
