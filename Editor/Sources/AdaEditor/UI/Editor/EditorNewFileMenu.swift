@_spi(AdaEngine) import AdaEngine

struct EditorNewFileMenu: View {
    let onSelect: (EditorNewFileKind) -> Void

    @State private var hoveredKind: EditorNewFileKind?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(EditorNewFileKind.allCases, id: \.self) { kind in
                templateRow(kind)
            }
        }
        .padding(4)
        .background(RoundedRectangleShape(cornerRadius: 7).fill(theme.editorColors.surfaceElevated))
        .overlay {
            RoundedRectangleShape(cornerRadius: 7)
                .stroke(theme.editorColors.border, lineWidth: 1)
        }
        .accessibilityIdentifier("AdaEditor.ProjectTree.New.Menu")
    }

    private func templateRow(_ kind: EditorNewFileKind) -> some View {
        Button {
            onSelect(kind)
        } label: {
            HStack(spacing: 8) {
                Text(kind.title)
                    .foregroundColor(theme.editorColors.text)
                Spacer()
                Text(".\(kind.fileExtension)")
                    .foregroundColor(theme.editorColors.muted)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .frame(width: 196, height: 32, alignment: .leading)
            .background(
                RoundedRectangleShape(cornerRadius: 5)
                    .fill(hoveredKind == kind ? theme.editorColors.blue.opacity(0.22) : Color.clear)
            )
        }
        .buttonStyle(DefaultButtonStyle())
        .onHover { isHovered in
            if isHovered {
                hoveredKind = kind
            } else if hoveredKind == kind {
                hoveredKind = nil
            }
        }
        .accessibilityIdentifier("AdaEditor.ProjectTree.New.\(kind.rawValue)")
    }
}
