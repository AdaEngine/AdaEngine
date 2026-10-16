import AdaECS

/// Developer visualizations of the 3D frame, selected per camera through ``Environment3D/debugView``.
///
/// Every mode except ``wireframe`` replaces the final image with data the main pass already writes
/// (normals, view position, roughness/metallic, indirect light) or that SSAO produces, so enabling a
/// view adds one fullscreen pass and `.none` adds nothing. ``wireframe`` draws the main pass with
/// line fill; backends without polygon fill modes (WebGPU) render it solid.
public enum DebugView3D: String, Codable, Sendable, CaseIterable {
    /// Normal rendering.
    case none
    /// View-space normals remapped to `0...1`.
    case normals
    /// Linear view depth, near surfaces dark and far surfaces light.
    case depth
    /// Perceptual roughness as grayscale.
    case roughness
    /// Metallic as grayscale.
    case metallic
    /// Filtered screen-space ambient occlusion. White when SSAO is disabled.
    case ambientOcclusion
    /// Ambient and image-based light the main pass accumulated before reflections, brightened with an
    /// exponential curve so the usually dim values are readable.
    case indirectLighting
    /// Main pass rendered with line fill.
    case wireframe

    /// Shader selector; ``none`` and ``wireframe`` never reach the debug pass.
    var shaderMode: Float {
        switch self {
        case .none, .wireframe: 0
        case .normals: 1
        case .depth: 2
        case .roughness: 3
        case .metallic: 4
        case .ambientOcclusion: 5
        case .indirectLighting: 6
        }
    }

    /// Whether the fullscreen debug pass replaces the final image.
    var replacesFinalImage: Bool {
        switch self {
        case .none, .wireframe: false
        default: true
        }
    }
}
