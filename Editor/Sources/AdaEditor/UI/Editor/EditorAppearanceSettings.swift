@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation

@Observable
@MainActor
final class EditorAppearanceSettings {
    static let shared = EditorAppearanceSettings()
    private static let glowKey = "AdaEditor.appearance.agentActivityGlowEnabled"
    @ObservationIgnored private let defaults: UserDefaults

    var agentActivityGlowEnabled: Bool {
        didSet { defaults.set(agentActivityGlowEnabled, forKey: Self.glowKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        agentActivityGlowEnabled = defaults.object(forKey: Self.glowKey) as? Bool ?? true
    }
}

struct EditorAgentGlowSettings: View {
    var settings: EditorAppearanceSettings = .shared
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorSettingsToggleRow(title: "Agent activity glow", isOn: settings.agentActivityGlowEnabled) {
                settings.agentActivityGlowEnabled.toggle()
            }
            .accessibilityIdentifier("AdaEditor.Settings.AgentActivityGlow")
            Text("Show colored window edges while an agent works or needs attention. Applies immediately to all editor windows.")
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
        }
    }
}
