@_spi(AdaEngine) import AdaEngine

struct EditorTopToolbar: View {
    let hotReloadState: EditorHotReloadState
    let viewModel: EditorToolbarViewModel
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 12) {
            Spacer(minLength: metrics.toolbarLeadingSpacerWidth)
            
            SearchBar(
                text: viewModel.searchTextBinding,
                prompt: "Search Everywhere"
            )
            .frame(minWidth: 256, maxWidth: 650)
            
            Spacer()
            
            if metrics.showsToolbarSceneName {
                Text(viewModel.sceneName)
                    .font(.system(size: 12))
                    .foregroundColor(theme.editorColors.muted)
            }
            
            adaEditorToolbarPill(hotReloadState.toolbarTitle, active: hotReloadState.isEnabled && hotReloadState.errorMessage == nil, theme: theme)
            
            Button(action: {}) {
                Text(metrics.showsRunButtonTitle ? "▶  Run" : "▶")
            }
            .font(.system(size: 12))
            .foregroundColor(Color(red: 110 / 255, green: 205 / 255, blue: 126 / 255))
            .padding(.horizontal, 12)
            .frame(height: 28)
            
            adaEditorToolbarPill("▾", active: false, theme: theme)
                .padding(.trailing, 12)
            
            Spacer()
        }
    }
}
