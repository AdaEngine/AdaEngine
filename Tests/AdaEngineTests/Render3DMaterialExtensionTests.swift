#if os(macOS)
import AdaECS
@_spi(Internal) import AdaRender
import AdaScene
import AdaTransform
import AdaUtils
import Foundation
import Math
import Testing

@testable import AdaCorePipelines

/// How material extension values become shader constants; no GPU needed.
@Suite("3D material extension constants")
struct Render3DMaterialExtensionConstantTests {
    @Test func defaultsGiveTheFourPercentReflectanceAndIdentityTransforms() {
        let uniform = PBR3DUniform(material: PBRMaterial(), descriptor: VertexDescriptor())
        #expect(abs(uniform.dielectric.x - 0.04) < 0.000001 && uniform.dielectric.x == uniform.dielectric.y)
        for transform in [uniform.transform0, uniform.transform1, uniform.transform2, uniform.transform3, uniform.transform4] {
            #expect(transform.matrix == Vector4(1, 0, 0, 1) && transform.offset == .zero)
        }
        let fallback = PBR3DUniform(material: nil, descriptor: VertexDescriptor())
        #expect(abs(fallback.dielectric.x - 0.04) < 0.000001)
    }

    @Test func iorAndSpecularScaleTheDielectricReflectance() {
        let material = PBRMaterial()
        material.ior = 1
        #expect(PBR3DUniform.dielectricReflectance(material) == .zero)
        material.ior = 3
        #expect(abs(PBR3DUniform.dielectricReflectance(material).x - 0.25) < 0.000001)
        material.specularFactor = 0.5
        #expect(abs(PBR3DUniform.dielectricReflectance(material).x - 0.125) < 0.000001)
        material.specularColorFactor = Vector3(1, 0.5, 0)
        let tinted = PBR3DUniform.dielectricReflectance(material)
        #expect(tinted.x > tinted.y && tinted.y > tinted.z && tinted.z == 0)
        material.ior = 100
        material.specularFactor = 1
        material.specularColorFactor = Vector3(50, 50, 50)
        #expect(PBR3DUniform.dielectricReflectance(material).x <= 1, "The tint cannot push reflectance beyond total reflection.")
    }

    @Test func clearcoatDefaultsToOffAndClampsToTheUnitRange() {
        #expect(PBR3DUniform(material: PBRMaterial(), descriptor: VertexDescriptor()).coat == .zero)
        #expect(PBR3DUniform(material: nil, descriptor: VertexDescriptor()).coat == .zero)
        let material = PBRMaterial()
        material.clearcoatFactor = 0.6
        material.clearcoatRoughnessFactor = 0.2
        #expect(PBR3DUniform(material: material, descriptor: VertexDescriptor()).coat == Vector4(0.6, 0.2, 0, 0))
        material.clearcoatFactor = 7
        material.clearcoatRoughnessFactor = .nan
        let wild = PBR3DUniform(material: material, descriptor: VertexDescriptor()).coat
        #expect(wild.x == 1 && wild.y.isFinite)
        let plain = PBR3DUniform(material: PBRMaterial(), descriptor: VertexDescriptor())
        #expect(plain.bitPatterns != PBR3DUniform(material: material, descriptor: VertexDescriptor()).bitPatterns)
    }

    @Test func sheenAndAnisotropyDefaultToOffAndClamp() {
        let plain = PBR3DUniform(material: PBRMaterial(), descriptor: VertexDescriptor())
        #expect(plain.sheen == .zero && plain.anisotropy == .zero)
        let material = PBRMaterial()
        material.sheenColorFactor = Vector3(0.9, 0.5, 0.2)
        material.sheenRoughnessFactor = 0.4
        material.anisotropyStrength = 0.6
        material.anisotropyRotation = 1.2
        let value = PBR3DUniform(material: material, descriptor: VertexDescriptor())
        #expect(value.sheen == Vector4(0.9, 0.5, 0.2, 0.4) && value.anisotropy == Vector4(0.6, 1.2, 0, 0))
        material.sheenColorFactor = Vector3(5, .nan, -1)
        material.anisotropyStrength = .infinity
        let wild = PBR3DUniform(material: material, descriptor: VertexDescriptor())
        #expect(wild.sheen.x == 1 && wild.sheen.y.isFinite && wild.sheen.z == 0 && wild.anisotropy.x.isFinite)
        #expect(plain.bitPatterns != value.bitPatterns && value.bitPatterns != wild.bitPatterns)
    }

    @Test func nonFiniteValuesFallBackToDefaults() {
        let material = PBRMaterial()
        material.ior = .nan
        material.specularFactor = .infinity
        material.specularColorFactor = Vector3(.nan, 1, 1)
        let value = PBR3DUniform.dielectricReflectance(material)
        #expect(value.x.isFinite && value.y.isFinite && value.z.isFinite)
    }

    @Test func textureTransformFollowsTheGlTFMatrix() {
        let rotated = PBR3DTextureTransform(PBRTextureTransform(offset: Vector2(0.5, 0.25), rotation: .pi / 2, scale: Vector2(2, 3)))
        // uv' = [cos*sx*u + sin*sy*v, -sin*sx*u + cos*sy*v] + offset
        #expect(abs(rotated.matrix.x) < 0.00001 && abs(rotated.matrix.y - 3) < 0.00001)
        #expect(abs(rotated.matrix.z + 2) < 0.00001 && abs(rotated.matrix.w) < 0.00001)
        #expect(rotated.offset == Vector4(0.5, 0.25, 0, 0))
    }

    @Test func materialEditsChangeTheRevisionAndTheSharedBuffer() {
        let material = PBRMaterial()
        let before = material.uniformRevision
        material.textureTransforms[0] = PBRTextureTransform(scale: Vector2(2, 2))
        material.ior = 1.8
        #expect(material.uniformRevision > before)
        let plain = PBR3DUniform(material: PBRMaterial(), descriptor: VertexDescriptor())
        let edited = PBR3DUniform(material: material, descriptor: VertexDescriptor())
        #expect(plain != edited && plain.bitPatterns != edited.bitPatterns)
        #expect(plain.bitPatterns == PBR3DUniform(material: PBRMaterial(), descriptor: VertexDescriptor()).bitPatterns)
    }
}

extension Render3DGPUTests {
    /// Run alone: `ADAENGINE_GOLDEN_METAL=1 swift test --filter Render3DGPUTests/MaterialExtensions`.
    @Suite("3D material extensions on GPU")
    @MainActor
    struct MaterialExtensions {
        private static func checker() -> Texture2D {
            var image = Image(width: 8, height: 8, color: .white)
            for y in 0..<8 {
                for x in 0..<8 where (x / 2 + y / 2) % 2 == 0 {
                    image.setPixel(in: Point(Float(x), Float(y)), color: Color(red: 0.9, green: 0.1, blue: 0.1))
                }
            }
            return Texture2D(image: image)
        }

        /// A large sphere in front of the camera, in the middle of the frame.
        private static func makeScene(polesSideways: Bool = false, _ configure: (PBRMaterial) -> Void) async throws -> (scene: Render3DGPUTests.DebugViews.Scene, material: PBRMaterial) {
            let scene = try await Render3DDebugViewGPUTests.makeScene()
            let material = PBRMaterial()
            material.baseColorFactor = [0.5, 0.5, 0.5, 1]
            material.metallicFactor = 0
            material.roughnessFactor = 0.2
            configure(material)
            scene.app.main.spawn("Probe") {
                Mesh3DComponent(mesh: Mesh.generateSphere(radius: 0.5, renderDevice: scene.device), materials: [material])
                Transform(rotation: polesSideways ? Quat(axis: Vector3(0, 0, 1), angle: .pi / 2) : .identity, position: [0, 0.5, -2.2])
            }
            return (scene, material)
        }

        private static func peakHighlight(_ image: Image) -> Color {
            var peak = Color.black
            var best: Float = 0
            for y in stride(from: 130, to: 350, by: 2) {
                for x in stride(from: 170, to: 470, by: 2) {
                    let pixel = image.getPixel(x: x, y: y)
                    let value = pixel.red + pixel.green + pixel.blue
                    if value > best {
                        best = value
                        peak = pixel
                    }
                }
            }
            return peak
        }

        /// The largest brightness a frame gained over `baseline` anywhere in the middle of the frame.
        private static func largestGain(_ image: Image, over baseline: Image) -> Float {
            var gain: Float = 0
            for y in stride(from: 130, to: 350, by: 2) {
                for x in stride(from: 170, to: 470, by: 2) {
                    let now = image.getPixel(x: x, y: y), before = baseline.getPixel(x: x, y: y)
                    gain = max(gain, (now.red + now.green + now.blue) - (before.red + before.green + before.blue))
                }
            }
            return gain
        }

        private static func matches(_ left: Image, _ right: Image) -> Bool {
            GoldenFrame.compare(left, right, tolerance: GoldenFrame.activeTolerance).passes(GoldenFrame.activeTolerance)
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func textureTransformsMoveScaleAndRotateTheTexture() async throws {
            let (scene, material) = try await Self.makeScene { $0.baseColorTexture = Self.checker() }
            let plain = try await scene.render(.none)
            material.textureTransforms[0] = PBRTextureTransform(scale: Vector2(3, 3))
            let scaled = try await scene.render(.none)
            material.textureTransforms[0] = PBRTextureTransform(offset: Vector2(0.3, 0.1))
            let shifted = try await scene.render(.none)
            material.textureTransforms[0] = PBRTextureTransform(rotation: 0.7)
            let rotated = try await scene.render(.none)
            for (name, image) in [("scale", scaled), ("offset", shifted), ("rotation", rotated)] {
                #expect(!Self.matches(plain, image), "A \\(name) transform must change how the texture appears.")
            }
            material.textureTransforms[0] = PBRTextureTransform(rotation: 2 * .pi)
            #expect(Self.matches(plain, try await scene.render(.none)), "A full turn must leave the texture where it was.")
            material.textureTransforms[0] = .identity
            #expect(Self.matches(plain, try await scene.render(.none)), "Resetting to the identity must restore the frame.")
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func aHigherIORBrightensTheHighlightAndZeroSpecularRemovesIt() async throws {
            let (scene, material) = try await Self.makeScene { _ in }
            let standard = Self.peakHighlight(try await scene.render(.none))
            material.ior = 3
            let strong = Self.peakHighlight(try await scene.render(.none))
            material.ior = 1.5
            material.specularFactor = 0
            let none = Self.peakHighlight(try await scene.render(.none))
            func total(_ color: Color) -> Float { color.red + color.green + color.blue }
            #expect(total(strong) > total(standard), "An IOR of 3 reflects more than 1.5 (\\(total(strong)) vs \\(total(standard))).")
            #expect(total(none) < total(standard), "No specular strength must dim the highlight (\\(total(none)) vs \\(total(standard))).")
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func specularColorTintsTheHighlight() async throws {
            let (scene, material) = try await Self.makeScene { $0.ior = 2.5 }
            let neutral = Self.peakHighlight(try await scene.render(.none))
            material.specularColorFactor = Vector3(1, 0, 0)
            let red = Self.peakHighlight(try await scene.render(.none))
            #expect(red.red - red.blue > neutral.red - neutral.blue, "A red specular tint must shift the highlight toward red.")
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func clearcoatAddsASharpHighlightToARoughSurface() async throws {
            let (scene, material) = try await Self.makeScene { $0.baseColorFactor = [0.03, 0.03, 0.03, 1]; $0.roughnessFactor = 0.9 }
            let baseline = try await scene.render(.none)
            material.clearcoatFactor = 1
            material.clearcoatRoughnessFactor = 0.05
            let glossy = Self.largestGain(try await scene.render(.none), over: baseline)
            material.clearcoatRoughnessFactor = 0.6
            let blurred = Self.largestGain(try await scene.render(.none), over: baseline)
            #expect(glossy > 0.3, "A smooth coat must add a bright highlight to rough paint (gain \(glossy)).")
            #expect(glossy > blurred, "A rougher coat must spread and dim the highlight (\(glossy) vs \(blurred)).")
            material.clearcoatFactor = 0
            #expect(Self.matches(baseline, try await scene.render(.none)), "Turning the coat off must restore the frame.")
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func clearcoatStrengthScalesTheCoatMonotonically() async throws {
            let (scene, material) = try await Self.makeScene { $0.baseColorFactor = [0.03, 0.03, 0.03, 1]; $0.roughnessFactor = 0.9; $0.clearcoatRoughnessFactor = 0.05 }
            let baseline = try await scene.render(.none)
            var gains: [Float] = []
            for strength: Float in [0.3, 0.7, 1] {
                material.clearcoatFactor = strength
                gains.append(Self.largestGain(try await scene.render(.none), over: baseline))
            }
            #expect(zip(gains, gains.dropFirst()).allSatisfy { $0 < $1 }, "The coat's highlight must grow with its strength: \(gains)")
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func sheenAddsSoftLightThatGrowsWithItsColorAndTurnsOff() async throws {
            let (scene, material) = try await Self.makeScene { $0.baseColorFactor = [0.03, 0.03, 0.03, 1]; $0.roughnessFactor = 0.9 }
            let baseline = try await scene.render(.none)
            material.sheenRoughnessFactor = 0.4
            var gains: [Float] = []
            for strength: Float in [0.3, 0.7, 1] {
                material.sheenColorFactor = Vector3(strength, strength, strength)
                gains.append(Self.largestGain(try await scene.render(.none), over: baseline))
            }
            #expect(gains[0] > 0.05, "Sheen must add light (gain \(gains[0])).")
            #expect(zip(gains, gains.dropFirst()).allSatisfy { $0 < $1 }, "Sheen must grow with its color: \(gains)")
            material.sheenColorFactor = .zero
            #expect(Self.matches(baseline, try await scene.render(.none)), "Turning sheen off must restore the frame.")
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func sheenColorTintsTheAddedLight() async throws {
            let (scene, material) = try await Self.makeScene { $0.baseColorFactor = [0.03, 0.03, 0.03, 1]; $0.roughnessFactor = 0.9; $0.sheenRoughnessFactor = 0.4 }
            material.sheenColorFactor = Vector3(1, 0, 0)
            let red = try await scene.render(.none)
            material.sheenColorFactor = Vector3(0, 0, 1)
            let blue = try await scene.render(.none)
            var redExcess: Float = 0
            for y in stride(from: 130, to: 350, by: 2) {
                for x in stride(from: 170, to: 470, by: 2) {
                    let a = red.getPixel(x: x, y: y), b = blue.getPixel(x: x, y: y)
                    redExcess += (a.red - a.blue) - (b.red - b.blue)
                }
            }
            #expect(redExcess > 0, "A red sheen must leave the surface redder than a blue one (\(redExcess)).")
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func anisotropyStretchesTheHighlightAndRotationTurnsIt() async throws {
            let (scene, material) = try await Self.makeScene { $0.baseColorFactor = [0.03, 0.03, 0.03, 1]; $0.roughnessFactor = 0.35 }
            let round = try await scene.render(.none)
            material.anisotropyStrength = 0.8
            let stretched = try await scene.render(.none)
            material.anisotropyRotation = .pi / 2
            let turned = try await scene.render(.none)
            #expect(!Self.matches(round, stretched), "Anisotropy must change the highlight.")
            #expect(!Self.matches(stretched, turned), "Rotating the stretch direction must change the highlight.")
            material.anisotropyRotation = .pi
            #expect(Self.matches(stretched, try await scene.render(.none)), "Half a turn flips the direction and must look the same.")
            material.anisotropyStrength = 0
            material.anisotropyRotation = 0
            #expect(Self.matches(round, try await scene.render(.none)), "Zero strength must restore the round highlight.")
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func clearcoatMatchesItsGoldenFrame() async throws {
            let (scene, _) = try await Self.makeScene {
                $0.baseColorFactor = [0.55, 0.04, 0.04, 1]
                $0.metallicFactor = 0
                $0.roughnessFactor = 0.5
                $0.clearcoatFactor = 1
                $0.clearcoatRoughnessFactor = 0.04
            }
            switch try GoldenFrame.check(try await scene.render(.none), name: "pbr-sphere-clearcoat") {
            case .recorded, .matched:
                break
            case .missingReference(let actual):
                Issue.record("No golden frame for pbr-sphere-clearcoat; record with ADAENGINE_GOLDEN_RECORD=1. Actual: \(actual.path)")
            case let .mismatched(comparison, actual, difference):
                Issue.record("pbr-sphere-clearcoat differs in \(comparison.differingPixels) pixels. Actual: \(actual.path), difference: \(difference.path)")
            }
        }

        private static func expectGolden(_ image: Image, named name: String) throws {
            switch try GoldenFrame.check(image, name: name) {
            case .recorded, .matched:
                break
            case .missingReference(let actual):
                Issue.record("No golden frame for \(name); record with ADAENGINE_GOLDEN_RECORD=1. Actual: \(actual.path)")
            case let .mismatched(comparison, actual, difference):
                Issue.record("\(name) differs in \(comparison.differingPixels) pixels. Actual: \(actual.path), difference: \(difference.path)")
            }
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func sheenAndAnisotropyMatchTheirGoldenFrames() async throws {
            let (velvet, _) = try await Self.makeScene {
                $0.baseColorFactor = [0.25, 0.02, 0.05, 1]
                $0.metallicFactor = 0
                $0.roughnessFactor = 0.85
                $0.sheenColorFactor = Vector3(0.9, 0.55, 0.65)
                $0.sheenRoughnessFactor = 0.45
            }
            try Self.expectGolden(try await velvet.render(.none), named: "pbr-sphere-sheen")
            // The sphere's UV poles degenerate, which shows in a derivative-based tangent frame, so keep them at the sides.
            let (brushed, _) = try await Self.makeScene(polesSideways: true) {
                $0.baseColorFactor = [0.8, 0.8, 0.82, 1]
                $0.metallicFactor = 1
                $0.roughnessFactor = 0.35
                $0.anisotropyStrength = 0.85
            }
            try Self.expectGolden(try await brushed.render(.none), named: "pbr-sphere-anisotropy")
        }

        @Test(.enabled(if: Render3DDebugViewGPUTests.enabled))
        func defaultExtensionValuesChangeNothing() async throws {
            let (scene, material) = try await Self.makeScene { _ in }
            let baseline = try await scene.render(.none)
            material.ior = 1.5
            material.specularFactor = 1
            material.specularColorFactor = .one
            material.textureTransforms = Array(repeating: .identity, count: 5)
            #expect(Self.matches(baseline, try await scene.render(.none)))
        }
    }
}
#endif
