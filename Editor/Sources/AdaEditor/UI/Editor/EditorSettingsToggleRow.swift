@_spi(AdaEngine) import AdaEngine

struct EditorSettingsToggleRow: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).font(.system(size: 13))
                Spacer()
                Text(isOn ? "On" : "Off")
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                ZStack(anchor: .leading) {
                    RoundedRectangleShape(cornerRadius: 10)
                        .fill(isOn ? theme.editorColors.blue : theme.editorColors.border)
                        .frame(width: 36, height: 20)
                    CircleShape().fill(Color.white)
                        .frame(width: 16, height: 16)
                        .offset(x: isOn ? 18 : 2)
                }
                .frame(width: 36, height: 20)
            }
            .foregroundColor(theme.editorColors.text)
            .padding(.horizontal, 12)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangleShape(cornerRadius: 7).fill(theme.editorColors.surface))
            .overlay { RoundedRectangleShape(cornerRadius: 7).stroke(theme.editorColors.border, lineWidth: 1) }
        }
        .buttonStyle(DefaultButtonStyle())
    }
}
