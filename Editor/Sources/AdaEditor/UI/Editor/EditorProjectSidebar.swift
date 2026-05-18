@_spi(AdaEngine) import AdaEngine

struct EditorProjectSidebar: View {
    let viewModel: EditorProjectSidebarViewModel
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            adaEditorPanelTitle("PROJECT", trailing: "", theme: theme)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.items, id: \.title) { item in
                        projectTreeRow(item)
                    }
                }
                .padding(8)
            }
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
        .mask(RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner))
    }

    private func projectTreeRow(_ item: EditorProjectSidebarViewModel.Item) -> some View {
        HStack(spacing: 6) {
            Text(item.disclosure).frame(width: 12)
            Text(item.icon).foregroundColor(item.isFolder ? theme.editorColors.blue : theme.editorColors.muted)
            Text(item.title)
            Spacer()
        }
        .font(.system(size: 12))
        .foregroundColor(item.isActive ? theme.editorColors.text : theme.editorColors.muted)
        .padding(.leading, Float(item.level) * 16)
        .padding(.horizontal, 6)
        .frame(height: 26)
        .background(RoundedRectangleShape(cornerRadius: 5).fill(item.isActive ? theme.editorColors.blue.opacity(0.22) : Color.clear))
        .accessibilityIdentifier("AdaEditor.ProjectTree.\(item.title)")
    }
}
