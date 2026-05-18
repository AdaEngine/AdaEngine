@_spi(AdaEngine) import AdaEngine

struct EditorProjectSidebar: View {
    let viewModel: EditorProjectSidebarViewModel
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.items, id: \.title) { item in
                        projectTreeRow(item)
                    }
                }
                .padding(8)
            }
            .background(
                theme.editorColors.surfaceElevated
                    .ignoresSafeArea()
            )
            .navigationBarColor(theme.editorColors.surfaceElevated)
            .navigationBarLeadingItems {
                Text("Project")
            }
//            .navigationBarTrailingItems {
//                
//            }
        }
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
