import Foundation
import Testing

@testable import AdaEditor

@Suite("AdaScript runtime settings and platforms")
struct AdaScriptRuntimeSettingsTests {
    /// The real catalog with audio marked unavailable on the web.
    private static let catalog: [EditorAdaScriptRuntimePluginDescriptor] = EditorAdaScriptRuntimePluginCatalog.descriptors.map { descriptor in
        descriptor.id == .audio
            ? EditorAdaScriptRuntimePluginDescriptor(
                dependencies: descriptor.dependencies,
                displayName: descriptor.displayName,
                id: descriptor.id,
                unavailablePlatforms: [.web]
            )
            : descriptor
    }

    @Test("a plugin unavailable on the platform fails unless the project disables it there")
    func unavailablePlatformFailsUnlessOverridden() throws {
        let plugins = AdaProjectRuntimePlugins(preset: .ui, enable: [.audio])

        #expect(throws: EditorRuntimePluginResolutionError.unavailableOnPlatform(plugin: "audio", platform: "web")) {
            try EditorAdaScriptRuntimePluginResolver.resolve(plugins, platform: .web, catalog: Self.catalog)
        }

        let onMac = try EditorAdaScriptRuntimePluginResolver.resolve(plugins, platform: .macOS, catalog: Self.catalog)
        #expect(onMac.contains(.audio))

        var overridden = plugins
        overridden.platformOverrides[AdaProjectRuntimePlatform.web.rawValue] = AdaProjectRuntimePluginOverride(disable: [.audio])
        let onWeb = try EditorAdaScriptRuntimePluginResolver.resolve(overridden, platform: .web, catalog: Self.catalog)
        #expect(!onWeb.contains(.audio))
        #expect(onWeb.platform == .web)
        // The override only applies to its own platform.
        let stillOnMac = try EditorAdaScriptRuntimePluginResolver.resolve(overridden, platform: .macOS, catalog: Self.catalog)
        #expect(stillOnMac.contains(.audio))
    }

    @Test("a platform override enables a plugin for that platform only")
    func overrideEnablesPluginPerPlatform() throws {
        var plugins = AdaProjectRuntimePlugins(preset: .ui)
        plugins.platformOverrides["android"] = AdaProjectRuntimePluginOverride(enable: [.audio])

        let android = try EditorAdaScriptRuntimePluginResolver.resolve(plugins, platform: .android)
        let linux = try EditorAdaScriptRuntimePluginResolver.resolve(plugins, platform: .linux)

        #expect(android.contains(.audio))
        #expect(!linux.contains(.audio))
    }

    @Test("a platform override wins over the shared lists and reports dependency conflicts")
    func overrideWinsOverSharedLists() throws {
        var plugins = AdaProjectRuntimePlugins(preset: .game2D, disable: [.audio])
        plugins.platformOverrides["macos"] = AdaProjectRuntimePluginOverride(enable: [.audio])
        #expect(try EditorAdaScriptRuntimePluginResolver.resolve(plugins, platform: .macOS).contains(.audio))
        #expect(try !EditorAdaScriptRuntimePluginResolver.resolve(plugins, platform: .linux).contains(.audio))

        var conflict = AdaProjectRuntimePlugins(preset: .game2D)
        conflict.platformOverrides["ios"] = AdaProjectRuntimePluginOverride(disable: [.sprite])
        #expect(throws: EditorRuntimePluginResolutionError.disabledDependency(plugin: "sprite", requiredBy: "tilemap")) {
            try EditorAdaScriptRuntimePluginResolver.resolve(conflict, platform: .iOS)
        }
        #expect(try EditorAdaScriptRuntimePluginResolver.resolve(conflict, platform: .linux).contains(.sprite))
    }

    @Test("unknown platforms and plugins in overrides are rejected")
    func unknownOverrideTargetsAreRejected() {
        var unknownPlatform = AdaProjectRuntimePlugins()
        unknownPlatform.platformOverrides["playstation"] = AdaProjectRuntimePluginOverride()
        #expect(throws: EditorRuntimePluginResolutionError.unknownPlatform("playstation")) {
            try EditorAdaScriptRuntimePluginResolver.resolve(unknownPlatform)
        }

        var unknownPlugin = AdaProjectRuntimePlugins()
        unknownPlugin.platformOverrides["web"] = AdaProjectRuntimePluginOverride(enable: [AdaProjectRuntimePluginID(rawValue: "ray-tracing")])
        #expect(throws: EditorRuntimePluginResolutionError.unknownPlugin("ray-tracing")) {
            try EditorAdaScriptRuntimePluginResolver.resolve(unknownPlugin, platform: .macOS)
        }
    }

    @Test("new setting groups round trip and stay out of default project files")
    func settingsGroupsRoundTrip() throws {
        let defaults = try JSONEncoder().encode(AdaProjectRuntimePlugins())
        let defaultJSON = try #require(String(data: defaults, encoding: .utf8))
        for key in ["physics3d", "audio", "rendering", "assets", "platformOverrides"] {
            #expect(!defaultJSON.contains(key))
        }

        let customized = AdaProjectRuntimePlugins(
            preset: .game3D,
            platformOverrides: ["web": AdaProjectRuntimePluginOverride(disable: [.audio])],
            settings: AdaProjectRuntimePluginSettings(
                physics3D: AdaProjectPhysics3DSettings(gravity: [0, -3.7, 0], subStepCount: 4),
                audio: AdaProjectAudioSettings(masterVolume: 0.25),
                rendering: AdaProjectRenderingSettings(upscaling: .spatial, renderScale: 0.6),
                assets: AdaProjectAssetSettings(preload: ["Assets/Textures/hero.png"])
            )
        )
        let decoded = try JSONDecoder().decode(AdaProjectRuntimePlugins.self, from: JSONEncoder().encode(customized))
        #expect(decoded == customized)

        let legacy = try JSONDecoder().decode(AdaProjectRuntimePlugins.self, from: Data(#"{"preset":"game2d","presetVersion":1}"#.utf8))
        #expect(legacy.settings.physics3D == AdaProjectPhysics3DSettings())
        #expect(legacy.settings.audio.masterVolume == 1)
        #expect(legacy.settings.rendering.upscaling == nil)
        #expect(legacy.settings.assets.preload.isEmpty)
        #expect(legacy.platformOverrides.isEmpty)
    }

    @Test("resolved settings reach the engine plugin parameters")
    func resolvedSettingsMapToEngineTypes() throws {
        var plugins = AdaProjectRuntimePlugins(preset: .game3D)
        plugins.settings.physics3D = AdaProjectPhysics3DSettings(gravity: [1, -2, 3], subStepCount: 5)
        plugins.settings.audio = AdaProjectAudioSettings(masterVolume: 0.5)
        plugins.settings.rendering = AdaProjectRenderingSettings(upscaling: .spatial, renderScale: 0.5)
        let resolved = try EditorAdaScriptRuntimePluginResolver.resolve(plugins, platform: .macOS)

        let physics = resolved.physics3DPlugin()
        #expect(physics.gravity.x == 1 && physics.gravity.y == -2 && physics.gravity.z == 3)
        #expect(physics.subStepCount == 5)
        #expect(resolved.renderUpscalingMode == .spatial(renderScale: 0.5))
        #expect(try EditorAdaScriptRuntimePluginResolver.resolve(AdaProjectRuntimePlugins(), platform: .macOS).renderUpscalingMode == nil)
    }

    @Test("settings validation rejects out of range values with their path")
    func validationRejectsInvalidSettings() throws {
        func invalidPath(_ mutate: (inout AdaProjectRuntimePlugins) -> Void) -> String? {
            var plugins = AdaProjectRuntimePlugins()
            mutate(&plugins)
            do {
                try ProjectSystem.validateRuntimePlugins(plugins)
                return nil
            } catch {
                if case let .invalidField(path, _) = error { return path }
                if case let .absolutePathNotAllowed(path, _) = error { return path }
                return "other"
            }
        }

        #expect(invalidPath { $0.settings.physics3D.gravity = [0, -9] } == "runtime.plugins.settings.physics3d.gravity")
        #expect(invalidPath { $0.settings.physics3D.gravity = [0, .infinity, 0] } == "runtime.plugins.settings.physics3d.gravity")
        #expect(invalidPath { $0.settings.physics3D.subStepCount = 0 } == "runtime.plugins.settings.physics3d.subStepCount")
        #expect(invalidPath { $0.settings.audio.masterVolume = 1.5 } == "runtime.plugins.settings.audio.masterVolume")
        #expect(invalidPath { $0.settings.audio.masterVolume = .nan } == "runtime.plugins.settings.audio.masterVolume")
        #expect(invalidPath { $0.settings.rendering.renderScale = 0.4 } == "runtime.plugins.settings.rendering.renderScale")
        #expect(invalidPath { $0.settings.assets.preload = ["/abs/hero.png"] } == "runtime.plugins.settings.assets.preload")
        #expect(invalidPath { $0.settings.assets.preload = ["a.png", "a.png"] } == "runtime.plugins.settings.assets.preload")
        #expect(invalidPath { $0.platformOverrides["playstation"] = AdaProjectRuntimePluginOverride() } == "runtime.plugins.platformOverrides")
        #expect(invalidPath { $0.platformOverrides["web"] = AdaProjectRuntimePluginOverride(enable: [.audio], disable: [.audio]) } == "runtime.plugins.platformOverrides.web")
        #expect(invalidPath { $0.settings.audio.masterVolume = 0.5 } == nil)
    }

    @Test("saving an AdaScript project persists a deterministic resolved runtime manifest")
    func savePersistsResolvedManifest() throws {
        let fileManager = FileManager.default
        let projectURL = fileManager.temporaryDirectory
            .appendingPathComponent("AdaScriptManifest-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: projectURL) }
        var project = ProjectSystem.defaultProject(projectName: "Manifest", buildSystem: .adaScript)
        project.runtime.plugins.preset = .game3D
        project.runtime.plugins.settings.physics3D.gravity = [0, -1.6, 0]
        project.runtime.plugins.settings.audio.masterVolume = 0.4

        try ProjectSystem.saveProject(project, at: projectURL, fileManager: fileManager)

        let url = projectURL.appendingPathComponent(ProjectSystemPath.runtimeManifestFile)
        let first = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(EditorAdaScriptResolvedRuntimeManifest.self, from: first)
        #expect(manifest.preset == .game3D)
        #expect(manifest.platform == .current)
        #expect(manifest.plugins.contains("physics3d"))
        #expect(!manifest.plugins.contains("physics2d"))
        #expect(manifest.physics3D?.gravity == [0, -1.6, 0])
        #expect(manifest.physics2D == nil)
        #expect(manifest.audio.masterVolume == 0.4)
        #expect(manifest.entry == project.runtime.entry)

        try ProjectSystem.saveProject(project, at: projectURL, fileManager: fileManager)
        #expect(try Data(contentsOf: url) == first)
    }

    @Test("the settings draft round trips the new groups and rejects invalid input")
    func draftAppliesNewGroups() throws {
        var draft = EditorRuntimeSettingsDraft(runtime: AdaProjectRuntime())
        #expect(draft.physics3DGravityY == "-9.81")
        #expect(draft.upscaling == nil)

        draft.physics3DGravityX = "1.5"
        draft.physics3DSubStepCount = "4"
        draft.audioMasterVolume = "0.3"
        draft.renderScale = "0.6"
        draft.upscaling = .spatial
        draft.preloadPaths = "Assets/a.png,\n Assets/b.png , "
        let runtime = try draft.applying(to: AdaProjectRuntime())

        #expect(runtime.plugins.settings.physics3D == AdaProjectPhysics3DSettings(gravity: [1.5, -9.81, 0], subStepCount: 4))
        #expect(runtime.plugins.settings.audio.masterVolume == 0.3)
        #expect(runtime.plugins.settings.rendering == AdaProjectRenderingSettings(upscaling: .spatial, renderScale: 0.6))
        #expect(runtime.plugins.settings.assets.preload == ["Assets/a.png", "Assets/b.png"])
        #expect(EditorRuntimeSettingsDraft(runtime: runtime).preloadPaths == "Assets/a.png, Assets/b.png")

        var invalid = draft
        invalid.audioMasterVolume = "2"
        #expect(throws: EditorRuntimeSettingsDraftError.invalidAudioMasterVolume) { try invalid.applying(to: runtime) }
        invalid = draft
        invalid.renderScale = "0.1"
        #expect(throws: EditorRuntimeSettingsDraftError.invalidRenderScale) { try invalid.applying(to: runtime) }
        invalid = draft
        invalid.physics3DSubStepCount = "0"
        #expect(throws: EditorRuntimeSettingsDraftError.invalidPhysics3DSubStepCount) { try invalid.applying(to: runtime) }
        invalid = draft
        invalid.physics3DGravityZ = "nan"
        #expect(throws: EditorRuntimeSettingsDraftError.invalidPhysics3DGravity) { try invalid.applying(to: runtime) }
    }
}
