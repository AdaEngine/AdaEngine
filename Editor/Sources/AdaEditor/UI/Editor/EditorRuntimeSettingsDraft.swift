import Foundation

struct EditorRuntimeSettingsDraft: Equatable, Sendable {
    var audioMasterVolume: String
    var gravityX: String
    var gravityY: String
    var physics3DGravityX: String
    var physics3DGravityY: String
    var physics3DGravityZ: String
    var physics3DSubStepCount: String
    var preloadPaths: String
    var renderScale: String
    var upscaling: AdaProjectRenderingSettings.Upscaling?
    var moduleName: String
    var scene: String
    var startupSystem: String
    var windowHeight: String
    var windowIsResizable: Bool
    var windowTitle: String
    var windowWidth: String

    init(runtime: AdaProjectRuntime = AdaProjectRuntime()) {
        let settings = runtime.plugins.settings
        let gravity3D = settings.physics3D.gravity + [0, 0, 0]
        self.audioMasterVolume = String(settings.audio.masterVolume)
        self.physics3DGravityX = String(gravity3D[0])
        self.physics3DGravityY = String(gravity3D[1])
        self.physics3DGravityZ = String(gravity3D[2])
        self.physics3DSubStepCount = String(settings.physics3D.subStepCount)
        self.preloadPaths = settings.assets.preload.joined(separator: ", ")
        self.renderScale = String(settings.rendering.renderScale)
        self.upscaling = settings.rendering.upscaling
        let gravity = runtime.plugins.settings.physics2D.gravity
        self.gravityX = gravity.first.map { String($0) } ?? "0.0"
        self.gravityY = gravity.dropFirst().first.map { String($0) } ?? "-9.81"
        self.moduleName = runtime.moduleName
        self.scene = runtime.entry.scene ?? ""
        self.startupSystem = runtime.entry.startupSystem ?? ""
        self.windowHeight = String(runtime.window.size.height)
        self.windowIsResizable = runtime.window.isResizable
        self.windowTitle = runtime.window.title ?? ""
        self.windowWidth = String(runtime.window.size.width)
    }

    func applying(to runtime: AdaProjectRuntime) throws -> AdaProjectRuntime {
        guard let width = Int(windowWidth), width > 0 else {
            throw EditorRuntimeSettingsDraftError.invalidWindowWidth
        }
        guard let height = Int(windowHeight), height > 0 else {
            throw EditorRuntimeSettingsDraftError.invalidWindowHeight
        }
        guard
            let gravityX = Double(gravityX), gravityX.isFinite,
            let gravityY = Double(gravityY), gravityY.isFinite
        else {
            throw EditorRuntimeSettingsDraftError.invalidPhysicsGravity
        }

        guard
            let gravity3DX = Double(physics3DGravityX), gravity3DX.isFinite,
            let gravity3DY = Double(physics3DGravityY), gravity3DY.isFinite,
            let gravity3DZ = Double(physics3DGravityZ), gravity3DZ.isFinite
        else {
            throw EditorRuntimeSettingsDraftError.invalidPhysics3DGravity
        }
        guard let subStepCount = Int(physics3DSubStepCount), (1...16).contains(subStepCount) else {
            throw EditorRuntimeSettingsDraftError.invalidPhysics3DSubStepCount
        }
        guard let masterVolume = Double(audioMasterVolume), masterVolume.isFinite, (0...1).contains(masterVolume) else {
            throw EditorRuntimeSettingsDraftError.invalidAudioMasterVolume
        }
        guard let scale = Double(renderScale), scale.isFinite, (0.5...1).contains(scale) else {
            throw EditorRuntimeSettingsDraftError.invalidRenderScale
        }

        var runtime = runtime
        runtime.plugins.settings.physics3D = AdaProjectPhysics3DSettings(
            gravity: [gravity3DX, gravity3DY, gravity3DZ],
            subStepCount: subStepCount
        )
        runtime.plugins.settings.audio = AdaProjectAudioSettings(masterVolume: masterVolume)
        runtime.plugins.settings.rendering = AdaProjectRenderingSettings(upscaling: upscaling, renderScale: scale)
        runtime.plugins.settings.assets = AdaProjectAssetSettings(
            preload: preloadPaths
                .split(whereSeparator: { $0.isNewline || $0 == "," })
                .compactMap { String($0).trimmedNilIfEmpty }
        )
        runtime.moduleName = moduleName.trimmingCharacters(in: .whitespacesAndNewlines)
        runtime.entry = AdaProjectRuntimeEntry(
            scene: scene.trimmedNilIfEmpty,
            startupSystem: startupSystem.trimmedNilIfEmpty,
            view: runtime.entry.view
        )
        runtime.plugins.settings.physics2D.gravity = [gravityX, gravityY]
        runtime.window = AdaProjectRuntimeWindow(
            title: windowTitle.trimmedNilIfEmpty,
            size: AdaProjectRuntimeWindowSize(width: width, height: height),
            isResizable: windowIsResizable
        )
        return runtime
    }
}

enum EditorRuntimeSettingsDraftError: Error, Equatable, LocalizedError, Sendable {
    case invalidAudioMasterVolume
    case invalidPhysicsGravity
    case invalidPhysics3DGravity
    case invalidPhysics3DSubStepCount
    case invalidRenderScale
    case invalidWindowHeight
    case invalidWindowWidth

    var errorDescription: String? {
        switch self {
        case .invalidAudioMasterVolume:
            "Audio master volume must be a number between 0 and 1."
        case .invalidPhysicsGravity:
            "Physics2D gravity must contain two finite numbers."
        case .invalidPhysics3DGravity:
            "Physics3D gravity must contain three finite numbers."
        case .invalidPhysics3DSubStepCount:
            "Physics3D sub-step count must be a whole number between 1 and 16."
        case .invalidRenderScale:
            "Render scale must be a number between 0.5 and 1."
        case .invalidWindowHeight:
            "Runtime window height must be a positive whole number."
        case .invalidWindowWidth:
            "Runtime window width must be a positive whole number."
        }
    }
}

extension String {
    var trimmedNilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
