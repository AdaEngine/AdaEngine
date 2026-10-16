#if os(macOS)
import AdaEngine
@_spi(Internal) import AdaRender
import AdaTransform
import Foundation
import Math
import Testing

@testable import AdaCorePipelines

/// Automatic exposure settings that need no GPU.
@Suite("3D auto exposure settings")
struct Render3DAutoExposureSettingsTests {
    @Test func defaultsAreOffWithAThreeStopRange() {
        let settings = AutoExposure3D()
        #expect(!settings.isEnabled)
        #expect(settings.minimumEV == -3 && settings.maximumEV == 3)
        #expect(PostProcess3D().autoExposure == settings)
    }

    @Test func olderPayloadsDecodeWithoutAutoExposure() throws {
        let decoded = try JSONDecoder().decode(PostProcess3D.self, from: Data(#"{"exposureEV":0.5}"#.utf8))
        #expect(decoded.autoExposure == AutoExposure3D())
        let partial = try JSONDecoder().decode(AutoExposure3D.self, from: Data(#"{"isEnabled":true,"maximumEV":5}"#.utf8))
        #expect(partial.isEnabled && partial.maximumEV == 5 && partial.minimumEV == -3)
    }

    @Test func settingsRoundTripAndFlatAccessor() throws {
        var environment = Environment3D()
        environment.autoExposureEnabled = true
        environment.postProcess.autoExposure = AutoExposure3D(isEnabled: true, minimumEV: -2, maximumEV: 4, speedUp: 0.5, speedDown: 3)
        let decoded = try JSONDecoder().decode(Environment3D.self, from: JSONEncoder().encode(environment))
        #expect(decoded.postProcess.autoExposure == environment.postProcess.autoExposure)
        #expect(decoded.autoExposureEnabled)
    }

    @Test func limitsAreOrderedClampedAndSpeedsFinite() {
        let swapped = AutoExposure3D(minimumEV: 4, maximumEV: -4).sanitized
        #expect(swapped.minimumEV == -4 && swapped.maximumEV == 4)
        let wild = AutoExposure3D(minimumEV: -100, maximumEV: .nan, speedUp: .nan, speedDown: -5).sanitized
        #expect(wild.minimumEV == -10)
        #expect(wild.maximumEV == AutoExposure3D().maximumEV)
        #expect(wild.speedUp == AutoExposure3D().speedUp)
        #expect(wild.speedDown == 0)
        #expect(AutoExposure3D(speedUp: .infinity, speedDown: .infinity).sanitized.speedUp == AutoExposure3D.snapSpeed)
        #expect(AutoExposure3D(speedUp: 5000).sanitized.speedUp == 1000)
    }
}

/// Renders automatic exposure through the real Metal pipeline.
///
/// Run alone: `ADAENGINE_GOLDEN_METAL=1 swift test --filter Render3DAutoExposureMetalTests`.
@Suite("3D auto exposure on Metal", .serialized)
@MainActor
struct Render3DAutoExposureMetalTests {
    /// Snaps to the metered exposure on every frame, so results do not depend on frame timing.
    private static let snapping = AutoExposure3D(isEnabled: true, minimumEV: -6, maximumEV: 6, speedUp: .infinity, speedDown: .infinity)
    private static let probes = [(320, 440), (100, 450), (150, 230), (200, 215)]

    private static func luminance(_ color: Color) -> Float { (color.red + color.green + color.blue) / 3 }

    private static func groundBrightness(_ image: Image) -> Float { luminance(image.getPixel(x: 320, y: 440)) }

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

    @Test(.enabled(if: Render3DDebugViewMetalTests.enabled), arguments: Render3DPostProcessMetalTests.Path.allCases)
    func aPinnedRangeMatchesManualExposureOnEveryPath(path: Render3DPostProcessMetalTests.Path) async throws {
        let scene = try await Render3DDebugViewMetalTests.makeScene(
            antiAliasing: path == .fxaa ? .fxaa : .none,
            temporalRenderScale: path == .temporal ? 1 : nil
        )
        // Temporal jitter repeats every eight frames, so renders of equal length land on the same phase.
        let frames = path == .temporal ? 16 : 6
        try scene.configure { $0.postProcess.exposureEV = 1 }
        let manual = try await scene.render(.none, frames: frames)
        try scene.configure {
            $0.postProcess.exposureEV = 0
            $0.postProcess.autoExposure = AutoExposure3D(isEnabled: true, minimumEV: 1, maximumEV: 1, speedUp: .infinity, speedDown: .infinity)
        }
        let automatic = try await scene.render(.none, frames: frames)
        for (x, y) in Self.probes {
            let left = automatic.getPixel(x: x, y: y), right = manual.getPixel(x: x, y: y)
            let difference = max(abs(left.red - right.red), abs(left.green - right.green), abs(left.blue - right.blue)) * 255
            #expect(difference <= (path == .temporal ? 6 : 3), "\(path): a +1 EV auto range differs from +1 EV manual by \(difference) steps at (\(x), \(y)).")
        }
    }

    @Test(.enabled(if: Render3DDebugViewMetalTests.enabled))
    func autoExposureEvensOutSceneBrightness() async throws {
        let scene = try await Render3DDebugViewMetalTests.makeScene()
        try scene.setSunIntensity(3)
        let brightManual = Self.groundBrightness(try await scene.render(.none))
        try scene.setSunIntensity(0.4)
        let dimManual = Self.groundBrightness(try await scene.render(.none))
        let manualSpread = abs(brightManual - dimManual)
        #expect(manualSpread > 0.1, "The two lighting levels must differ visibly without auto exposure (\(manualSpread)).")

        try scene.configure { $0.postProcess.autoExposure = Self.snapping }
        try scene.setSunIntensity(3)
        let brightAuto = Self.groundBrightness(try await scene.render(.none, frames: 6))
        try scene.setSunIntensity(0.4)
        let dimAuto = Self.groundBrightness(try await scene.render(.none, frames: 6))
        let autoSpread = abs(brightAuto - dimAuto)
        #expect(autoSpread < manualSpread * 0.5, "Auto exposure must narrow the brightness gap: \(autoSpread) against \(manualSpread) without it.")
        // Both scenes average below mid gray, so both are brightened, the dimmer one by more.
        #expect(dimAuto > dimManual + 0.05, "A dim scene must be brightened.")
        #expect(dimAuto - dimManual > brightAuto - brightManual, "The dim scene must gain more than the bright one.")
        try scene.setSunIntensity(0.4)
        try Self.expectGolden(try await scene.render(.none, frames: 6), named: "pbr-spheres-dim-autoexposure")
        try scene.configure { $0.postProcess.autoExposure.isEnabled = false }
        try Self.expectGolden(try await scene.render(.none, frames: 6), named: "pbr-spheres-dim-manual")
    }

    @Test(.enabled(if: Render3DDebugViewMetalTests.enabled))
    func adaptationSpeedControlsHowFastExposureFollowsTheScene() async throws {
        let slowScene = try await Render3DDebugViewMetalTests.makeScene()
        try slowScene.setSunIntensity(3)
        try slowScene.configure { $0.postProcess.autoExposure = AutoExposure3D(isEnabled: true, minimumEV: -6, maximumEV: 6, speedUp: 0.001, speedDown: 0.001) }
        let before = Self.groundBrightness(try await slowScene.render(.none, frames: 6))
        try slowScene.setSunIntensity(0.4)
        let slow = Self.groundBrightness(try await slowScene.render(.none, frames: 6))

        let snapScene = try await Render3DDebugViewMetalTests.makeScene()
        try snapScene.setSunIntensity(3)
        try snapScene.configure { $0.postProcess.autoExposure = Self.snapping }
        _ = try await snapScene.render(.none, frames: 6)
        try snapScene.setSunIntensity(0.4)
        let snapped = Self.groundBrightness(try await snapScene.render(.none, frames: 6))

        #expect(slow < before, "The dimmer scene reads darker while exposure has barely moved.")
        #expect(snapped > slow + 0.08, "Snapping must have re-exposed the dim scene (\(snapped)) well beyond the sluggish one (\(slow)).")
    }

    @Test(.enabled(if: Render3DDebugViewMetalTests.enabled))
    func disabledAutoExposureChangesNothingAndHoldsNoState() async throws {
        let scene = try await Render3DDebugViewMetalTests.makeScene()
        let renderWorld = try #require(scene.app.getSubworldBuilder(by: .renderWorld)?.main)
        func views() throws -> AutoExposure3DViews { try #require(renderWorld.getResource(AutoExposure3DViews.self)) }
        let baseline = try await scene.render(.none)
        try scene.configure { $0.postProcess.autoExposure = AutoExposure3D(isEnabled: false, minimumEV: 5, maximumEV: 5) }
        let off = try await scene.render(.none)
        #expect(GoldenFrame.compare(baseline, off, tolerance: .metal).passes(.metal))
        #expect(try views().output(view: scene.camera.id) == nil)

        try scene.configure { $0.postProcess.autoExposure = Self.snapping }
        _ = try await scene.render(.none)
        #expect(try views().output(view: scene.camera.id)?.size == SizeInt(width: 1, height: 1))
        try scene.configure { $0.postProcess.autoExposure.isEnabled = false }
        let released = try await scene.render(.none)
        #expect(try views().output(view: scene.camera.id) == nil, "Turning it off must release the state.")
        #expect(GoldenFrame.compare(baseline, released, tolerance: .metal).passes(.metal))
    }

    @Test(.enabled(if: Render3DDebugViewMetalTests.enabled))
    func aFrameWithoutGeometryHoldsTheLastExposure() async throws {
        let scene = try await Render3DDebugViewMetalTests.makeScene()
        try scene.setSunIntensity(0.4)
        let skyOff = Self.luminance(try await scene.render(.none).getPixel(x: 320, y: 40))
        try scene.configure { $0.postProcess.autoExposure = Self.snapping }
        let skyMetered = Self.luminance(try await scene.render(.none, frames: 6).getPixel(x: 320, y: 40))
        #expect(abs(skyMetered - skyOff) > 0.04, "The dim scene must have changed exposure, so the sky reads differently (\(skyMetered) vs \(skyOff)).")
        // Look straight up: nothing but sky is covered, so the meter has nothing to average.
        var transform = try #require(scene.camera.components[Transform.self])
        transform.rotation = Quat(axis: .right, angle: -1.2)
        scene.camera.components[Transform.self] = transform
        let skyOnly = try await scene.render(.none, frames: 6)
        #expect(abs(Self.luminance(skyOnly.getPixel(x: 320, y: 240)) - skyMetered) <= 0.02, "Exposure must hold when no geometry is visible.")
    }
}
#endif
