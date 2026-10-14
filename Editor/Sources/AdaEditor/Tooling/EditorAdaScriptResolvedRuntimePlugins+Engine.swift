@_spi(AdaEngine) import AdaEngine
import Foundation

/// Engine plugin construction for resolved project settings, shared by every runtime host.
extension EditorAdaScriptResolvedRuntimePlugins {
    func physics3DPlugin() -> Physics3DPlugin {
        Physics3DPlugin(
            gravity: Vector3(Float(physics3D.gravity[0]), Float(physics3D.gravity[1]), Float(physics3D.gravity[2])),
            subStepCount: Int32(physics3D.subStepCount)
        )
    }

    func audioPlugin() -> AudioPlugin {
        AudioPlugin(masterVolume: Float(audio.masterVolume))
    }

    /// The window-level upscaling mode, or `nil` to keep the platform default.
    var renderUpscalingMode: RenderUpscalingMode? {
        switch rendering.upscaling {
        case .none: nil
        case .disabled?: .disabled
        case .spatial?: .spatial(renderScale: Float(rendering.renderScale))
        }
    }
}
