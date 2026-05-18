@_spi(AdaEngine) import AdaEngine

struct EditorFooter: View {
    let hotReloadState: EditorHotReloadState
    let viewModel: EditorFooterViewModel
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 14) {
            ForEach(viewModel.leftItems(hotReloadState: hotReloadState), id: \.self) {
                Text($0)
            }
            Spacer()
            if metrics.showsFooterRight {
                ForEach(viewModel.rightItems, id: \.self) {
                    Text($0)
                }
            }
        }
        .font(.system(size: 10))
        .foregroundColor(theme.editorColors.text)
        .padding(.horizontal, 10)
    }
}
