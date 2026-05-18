@_spi(AdaEngine) import AdaEngine

struct EditorInspectorSidebar: View {
    let viewModel: EditorInspectorSidebarViewModel
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            adaEditorPanelTitle("INSPECTOR", trailing: "", theme: theme)
            inspectorSection("TRANSFORM") {
                ForEach(viewModel.transformFields, id: \.label) { field in
                    transformRow(field.label, value: field.value)
                }
            }
            Spacer()
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
    }

    private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12)).foregroundColor(theme.editorColors.blue)
            content()
        }
        .padding(12)
    }

    private func transformRow(_ label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 11)).foregroundColor(theme.editorColors.muted).frame(width: 88, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.text)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangleShape(cornerRadius: 4).fill(theme.editorColors.surfaceElevated))
                .overlay { RoundedRectangleShape(cornerRadius: 4).stroke(theme.editorColors.border, lineWidth: 1) }
        }
    }
}
