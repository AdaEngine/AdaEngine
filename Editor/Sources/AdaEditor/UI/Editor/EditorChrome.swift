@_spi(AdaEngine) import AdaEngine

@MainActor
func adaEditorPanelTitle(_ title: String, trailing: String, theme: Theme) -> some View {
    let colors = theme.editorColors
    return HStack(spacing: 8) {
        Text(title)
            .font(.system(size: 12))
            .foregroundColor(colors.muted)
            .lineLimit(1)
        if !trailing.isEmpty {
            Text(trailing)
                .font(.system(size: 11))
                .foregroundColor(colors.muted)
                .lineLimit(1)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
        } else {
            Spacer()
        }
    }
    .padding(.horizontal, 12)
    .frame(height: 34)
}

@MainActor
func adaEditorToolbarPill(_ text: String, active: Bool, theme: Theme) -> some View {
    let colors = theme.editorColors
    return Text(text)
        .font(.system(size: 12))
        .foregroundColor(active ? colors.blue : colors.text)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(RoundedRectangleShape(cornerRadius: 7).fill(active ? colors.blue.opacity(0.16) : colors.background))
        .overlay { RoundedRectangleShape(cornerRadius: 7).stroke(colors.border, lineWidth: 1) }
}

@MainActor
func adaEditorStripButton(
    _ item: EditorToolStripItem,
    active: Bool,
    theme: Theme,
    accent: Color? = nil,
    action: @escaping () -> Void = {}
) -> some View {
    Button(action: action) {
        Text(item.icon)
            .font(AdaEditorMaterialSymbolFont.font(size: 18))
            .frame(width: 30, height: 30)
    }
    .buttonStyle(
        AdaEditorStripButtonStyle(
            active: active,
            theme: theme,
            accent: accent
        )
    )
    .accessibilityIdentifier("AdaEditor.ToolStrip.\(item.identifier)")
}

enum AdaEditorMaterialSymbolFont {
    static let codepoints: [UInt32] = [
        0xE0CA,
        0xE2C7,
        0xE48F,
        0xE5CD,
        0xE71C,
        0xE869,
        0xE86C,
        0xE87B,
        0xE88E,
        0xE8B6,
        0xE8B8,
        0xE97A,
        0xEB8E,
        0xF1C4,
        0xF720
    ]

    private static let resource: FontResource? = {
        guard let fontURL = Foundation.Bundle.editor.url(
            forResource: "MaterialSymbolsRounded-Regular",
            withExtension: "ttf",
            subdirectory: "Assets/Fonts"
        ) else {
            return nil
        }

        return FontResource.custom(
            fontPath: fontURL,
            emFontScale: 96,
            includeDefaultCharset: false,
            additionalCodepoints: codepoints
        )
    }()

    static func font(size: Double) -> Font {
        guard let resource else {
            return .system(size: size)
        }

        return Font(fontResource: resource, pointSize: size)
    }
}

private struct AdaEditorStripButtonStyle: ButtonStyle {
    let active: Bool
    let theme: Theme
    let accent: Color?

    func makeBody(configuration: Configuration) -> some View {
        let colors = theme.editorColors
        let accentColor = accent ?? colors.blue
        let isHighlighted = configuration.state.isHighlighted || configuration.state.isSelected

        return configuration.label
            .foregroundColor(active ? accentColor : (isHighlighted ? colors.text : colors.muted))
            .frame(width: 30, height: 30)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(active ? accentColor.opacity(0.16) : (isHighlighted ? colors.surfaceElevated : Color.clear)))
            .overlay {
                HStack(spacing: 0) {
                    if active { RectangleShape().fill(accentColor).frame(width: 3, height: 18) }
                    Spacer()
                }
            }
        }
}
