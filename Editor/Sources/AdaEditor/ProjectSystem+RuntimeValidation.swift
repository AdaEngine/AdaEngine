import Foundation

extension ProjectSystem {
    static func validateRuntimePlugins(_ plugins: AdaProjectRuntimePlugins) throws(ProjectSystemError) {
        guard plugins.presetVersion == AdaProjectRuntimePlugins.currentPresetVersion else {
            throw .invalidField(
                path: "runtime.plugins.presetVersion",
                message: "Unsupported plugin preset version \(plugins.presetVersion)."
            )
        }
        let enabled = Set(plugins.enable)
        let disabled = Set(plugins.disable)
        guard enabled.count == plugins.enable.count else {
            throw .invalidField(path: "runtime.plugins.enable", message: "Plugin identifiers must be unique.")
        }
        guard disabled.count == plugins.disable.count else {
            throw .invalidField(path: "runtime.plugins.disable", message: "Plugin identifiers must be unique.")
        }
        if let unknown = enabled.union(disabled)
            .subtracting(AdaProjectRuntimePluginID.knownValues)
            .min(by: { $0.rawValue < $1.rawValue }) {
            throw .invalidField(path: "runtime.plugins", message: "Unknown runtime plugin '\(unknown.rawValue)'.")
        }
        if let overlap = enabled.intersection(disabled).min(by: { $0.rawValue < $1.rawValue }) {
            throw .invalidField(
                path: "runtime.plugins",
                message: "Runtime plugin '\(overlap.rawValue)' cannot be both enabled and disabled."
            )
        }
        let gravity = plugins.settings.physics2D.gravity
        guard gravity.count == 2, gravity.allSatisfy(\.isFinite) else {
            throw .invalidField(
                path: "runtime.plugins.settings.physics2d.gravity",
                message: "Physics2D gravity must contain two finite numbers."
            )
        }
        let physics3D = plugins.settings.physics3D
        guard physics3D.gravity.count == 3, physics3D.gravity.allSatisfy(\.isFinite) else {
            throw .invalidField(
                path: "runtime.plugins.settings.physics3d.gravity",
                message: "Physics3D gravity must contain three finite numbers."
            )
        }
        guard (1...16).contains(physics3D.subStepCount) else {
            throw .invalidField(
                path: "runtime.plugins.settings.physics3d.subStepCount",
                message: "Physics3D subStepCount must be between 1 and 16."
            )
        }
        let volume = plugins.settings.audio.masterVolume
        guard volume.isFinite, (0...1).contains(volume) else {
            throw .invalidField(
                path: "runtime.plugins.settings.audio.masterVolume",
                message: "Audio masterVolume must be between 0 and 1."
            )
        }
        let rendering = plugins.settings.rendering
        guard rendering.renderScale.isFinite, (0.5...1).contains(rendering.renderScale) else {
            throw .invalidField(
                path: "runtime.plugins.settings.rendering.renderScale",
                message: "Rendering renderScale must be between 0.5 and 1."
            )
        }
        try validatePreloadPaths(plugins.settings.assets.preload)
        for (key, platformOverride) in plugins.platformOverrides.sorted(by: { $0.key < $1.key }) {
            guard AdaProjectRuntimePlatform(rawValue: key) != nil else {
                throw .invalidField(path: "runtime.plugins.platformOverrides", message: "Unknown runtime platform '\(key)'.")
            }
            let overrideEnabled = Set(platformOverride.enable)
            let overrideDisabled = Set(platformOverride.disable)
            guard overrideEnabled.count == platformOverride.enable.count, overrideDisabled.count == platformOverride.disable.count else {
                throw .invalidField(path: "runtime.plugins.platformOverrides.\(key)", message: "Plugin identifiers must be unique.")
            }
            if let unknown = overrideEnabled.union(overrideDisabled)
                .subtracting(AdaProjectRuntimePluginID.knownValues)
                .min(by: { $0.rawValue < $1.rawValue }) {
                throw .invalidField(
                    path: "runtime.plugins.platformOverrides.\(key)",
                    message: "Unknown runtime plugin '\(unknown.rawValue)'."
                )
            }
            if let overlap = overrideEnabled.intersection(overrideDisabled).min(by: { $0.rawValue < $1.rawValue }) {
                throw .invalidField(
                    path: "runtime.plugins.platformOverrides.\(key)",
                    message: "Runtime plugin '\(overlap.rawValue)' cannot be both enabled and disabled."
                )
            }
        }
        let multiplayer = plugins.settings.multiplayer
        guard ["host", "peer"].contains(multiplayer.role) else {
            throw .invalidField(
                path: "runtime.plugins.settings.multiplayer.role",
                message: "Multiplayer role must be host or peer."
            )
        }
        guard (1...65_535).contains(multiplayer.port) else {
            throw .invalidField(
                path: "runtime.plugins.settings.multiplayer.port",
                message: "Multiplayer port must be between 1 and 65535."
            )
        }
        guard (1...255).contains(multiplayer.peerIndex) else {
            throw .invalidField(
                path: "runtime.plugins.settings.multiplayer.peerIndex",
                message: "Multiplayer peerIndex must be between 1 and 255."
            )
        }
    }

    private static func validatePreloadPaths(_ paths: [String]) throws(ProjectSystemError) {
        guard Set(paths).count == paths.count else {
            throw .invalidField(path: "runtime.plugins.settings.assets.preload", message: "Preload paths must be unique.")
        }
        for path in paths {
            try validateRelativePath(path, keyPath: "runtime.plugins.settings.assets.preload")
        }
    }

    static func validateRuntimeWindow(_ window: AdaProjectRuntimeWindow) throws(ProjectSystemError) {
        let size = window.size
        guard (1...16_384).contains(size.width) else {
            throw .invalidField(path: "runtime.window.size.width", message: "Window width must be between 1 and 16384.")
        }
        guard (1...16_384).contains(size.height) else {
            throw .invalidField(path: "runtime.window.size.height", message: "Window height must be between 1 and 16384.")
        }
    }
}
