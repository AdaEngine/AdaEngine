@_spi(AdaEngine) import AdaEngine

struct EditorEnumField: View {
    let cases: [String]
    let selection: Binding<String>
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Text(selection.wrappedValue).lineLimit(1)
            Spacer()
            Text("\u{E5CF}")
                .font(AdaEditorMaterialSymbolFont.font(size: 16))
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(size: 12))
        .foregroundColor(theme.editorColors.text)
        .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surfaceElevated))
        .overlay { RoundedRectangleShape(cornerRadius: 6).stroke(theme.editorColors.border.opacity(0.6), lineWidth: 1) }
        .contextMenu(opensOnPrimaryAction: true) {
            ForEach(cases, id: \.self) { value in
                Button(selection.wrappedValue == value ? "✓ \(value)" : value) {
                    selection.wrappedValue = value
                }
            }
        }
        .accessibilityIdentifier("AdaEditor.Enum.Toggle")
    }
}
