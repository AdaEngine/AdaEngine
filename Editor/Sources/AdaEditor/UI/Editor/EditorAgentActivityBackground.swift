@_spi(AdaEngine) import AdaEngine
import AdaUI
import Foundation
import Math

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct EditorAgentActivityBackground: UIViewRepresentable {
    let state: EditorAgentActivityState
    let accent: Color
    var cornerRadius: Float = 14

    func makeUIView(in context: Context) -> EditorAgentActivityBackgroundView {
        let view = EditorAgentActivityBackgroundView()
        view.backgroundColor = .clear
        view.isInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: EditorAgentActivityBackgroundView, in context: Context) {
        view.configure(
            state: state,
            accent: accent,
            cornerRadius: cornerRadius
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, view: EditorAgentActivityBackgroundView, context: Context) -> Size {
        proposal.replacingUnspecifiedDimensions()
    }
}

struct EditorAgentActivityOverlay: View {
    let state: EditorAgentActivityState
    var settings: EditorAppearanceSettings = .shared
    @Environment(\.theme) private var theme

    @ViewBuilder var body: some View {
        if settings.agentActivityGlowEnabled {
            GeometryReader { geometry in
                EditorAgentActivityBackground(
                    state: state,
                    accent: theme.editorColors.blue,
                    cornerRadius: 14
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

/// Kept outside the observed editor tree: animation updates uniforms, never panel layout.
final class EditorAgentActivityBackgroundView: AdaUI.UIView {
    private(set) var animation = EditorAgentGlowAnimation()
    private var material: CustomMaterial<EditorAgentGlowMaterial>?
    private weak var renderWindow: AdaUI.UIWindow?
    private var cornerRadius: Float = 14

    func configure(state: EditorAgentActivityState, accent: Color, cornerRadius: Float = 14) {
        isInteractionEnabled = false
        if self.cornerRadius != cornerRadius {
            self.cornerRadius = cornerRadius
            setNeedsDisplay()
        }
        if animation.configure(state: state, accent: accent) { setNeedsDisplay() }
    }

    override func update(_ deltaTime: Float) {
        guard !isHidden, renderWindow?.canDraw != false else {
            return
        }
        // Unfocused windows still show the latest status, without continuous motion.
        let usesStaticStatus = Self.reduceMotion || renderWindow?.isActive == false
        if animation.advance(deltaTime, reduceMotion: usesStaticStatus) { setNeedsDisplay() }
    }

    override func draw(in rect: Rect, with context: UIGraphicsContext) {
        if let id = context.windowId { renderWindow = UIWindowManager.shared.windows[id] }
        guard animation.intensity > 0, rect.width > 2, rect.height > 2 else {
            return
        }
        if material == nil { material = CustomMaterial(EditorAgentGlowMaterial()) }
        guard let material else {
            return
        }
        material.parameters = EditorAgentGlowParameters(
            color: animation.color,
            geometry: Vector4(rect.width, rect.height, animation.time, 42),
            style: Vector4(animation.intensity, animation.hueSpread, cornerRadius, context.opacity)
        )
        context.drawShaderEffect(rect, material: material)
    }

    private static var reduceMotion: Bool {
        #if os(macOS)
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #elseif canImport(UIKit)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }
}

struct EditorAgentGlowAnimation {
    private(set) var color = Color.clear
    private(set) var intensity: Float = 0
    private(set) var time: Float = 5
    private(set) var hueSpread: Float = 0.065
    private(set) var motion: Float = 0
    private var state: EditorAgentActivityState = .idle
    private var accent = Color.clear

    mutating func configure(state: EditorAgentActivityState, accent: Color) -> Bool {
        guard self.state != state || self.accent != accent else {
            return false
        }
        // Start a fade from the intended hue, rather than from transparent black.
        if intensity == 0 { color = state.color(accent: accent) }
        self.state = state
        self.accent = accent
        return true
    }

    /// Returns false once the image is static; no recurring invalidation while idle or completed.
    @discardableResult
    mutating func advance(_ deltaTime: Float, reduceMotion: Bool) -> Bool {
        let delta = deltaTime.isFinite ? min(max(deltaTime, 0), 0.05) : 0
        let blend: Float = reduceMotion ? 1 : 1 - exp(-delta * 14)
        var changed = false
        func ease(_ current: Float, _ target: Float) -> Float {
            let next = current + (target - current) * blend
            let resolved = abs(next - target) < 0.001 ? target : next
            changed = changed || resolved != current
            return resolved
        }
        let targetColor = state.color(accent: accent)
        color = Color(
            red: ease(color.red, targetColor.red),
            green: ease(color.green, targetColor.green),
            blue: ease(color.blue, targetColor.blue)
        )
        intensity = ease(intensity, state.intensity)
        motion = ease(motion, state.motion)
        hueSpread = ease(hueSpread, state == .working || state == .idle ? 0.065 : 0.012)
        if !reduceMotion, motion > 0, intensity > 0, delta > 0 {
            time += delta * motion
            changed = true
        }
        return changed
    }
}

struct EditorAgentGlowParameters {
    var color: Color
    var geometry: Vector4
    var style: Vector4
}

struct EditorAgentGlowMaterial: UIShaderMaterial {
    // MaterialStorage binds complete reflected blocks, not individual GLSL members.
    @Uniform(binding: 0, propertyName: "EditorAgentGlowMaterial") var parameters: EditorAgentGlowParameters

    init() {
        parameters = EditorAgentGlowParameters(color: .clear, geometry: Vector4(1, 1, 0, 42), style: Vector4(0, 0.065, 14, 1))
    }

    static func fragmentShader() throws -> AssetHandle<ShaderSource> {
        guard let url = Bundle.editor.url(forResource: "agent_activity", withExtension: "glsl", subdirectory: "Assets/Shaders") else {
            throw EditorAgentGlowResourceError.missingShader
        }
        return AssetHandle(try ShaderSource(from: url))
    }

    static func configurePipeline(
        keys: Set<String>, vertex: Shader, fragment: Shader, vertexDescriptor: VertexDescriptor
    ) throws -> RenderPipelineDescriptor {
        var descriptor = RenderPipelineDescriptor(vertex: vertex)
        descriptor.debugName = "Editor Agent Background"
        descriptor.fragment = fragment
        descriptor.vertexDescriptor = vertexDescriptor
        descriptor.backfaceCulling = true
        descriptor.colorAttachments = [
            RenderPipelineColorAttachmentDescriptor(format: .bgra8, isBlendingEnabled: true, sourceRGBBlendFactor: .one)
        ]
        return descriptor
    }
}

private enum EditorAgentGlowResourceError: LocalizedError {
    case missingShader
    var errorDescription: String? { "Agent activity shader resource is missing." }
}
