@_spi(AdaEngine) import AdaEngine

@MainActor
func adaEditorPanelTitle(_ title: String, trailing: String, theme: Theme) -> some View {
    let colors = theme.editorColors
    return HStack {
        Text(title).font(.system(size: 12)).foregroundColor(colors.muted)
        Spacer()
        if !trailing.isEmpty {
            Text(trailing).font(.system(size: 11)).foregroundColor(colors.muted)
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
    _ title: String,
    icon: String,
    active: Bool,
    hoveredTool: String?,
    setHoveredTool: @MainActor @escaping (String?) -> Void,
    theme: Theme,
    accent: Color? = nil
) -> some View {
    let colors = theme.editorColors
    let accentColor = accent ?? colors.blue

    return Text(icon)
        .font(.system(size: 16))
        .foregroundColor(active ? accentColor : (hoveredTool == title ? colors.text : colors.muted))
        .frame(width: 30, height: 30)
        .background(RoundedRectangleShape(cornerRadius: 6).fill(active ? accentColor.opacity(0.16) : (hoveredTool == title ? colors.surfaceElevated : Color.clear)))
        .overlay {
            HStack(spacing: 0) {
                if active { RectangleShape().fill(accentColor).frame(width: 3, height: 18) }
                Spacer()
            }
        }
        .onHover { setHoveredTool($0 ? title : nil) }
        .accessibilityIdentifier("AdaEditor.ToolStrip.\(title)")
}
