import AdaEngine

struct EditorLanguageSettings: View {
    private let localization = EditorLocalization.shared
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("Application language"))
                .font(.system(size: 16, weight: .bold))
            Text(L10n.tr("Choose the language you want to read. Changes apply immediately."))
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.muted)
            ForEach(EditorLanguage.allCases, id: \.self) { language in
                Button {
                    localization.preference = language
                } label: {
                    HStack(spacing: 12) {
                        Text(L10n.tr(language.title))
                            .font(.system(size: 14))
                        Spacer()
                        if localization.preference == language {
                            Text("✓").foregroundColor(theme.editorColors.blue)
                        }
                    }
                    .padding(12)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(RoundedRectangleShape(cornerRadius: 8).fill(theme.editorColors.surfaceElevated))
                }
                .buttonStyle(DefaultButtonStyle())
                .accessibilityIdentifier("AdaEditor.Settings.Language.\(language.rawValue)")
            }
        }
        .foregroundColor(theme.editorColors.text)
        .accessibilityIdentifier("AdaEditor.Settings.Language")
    }
}
