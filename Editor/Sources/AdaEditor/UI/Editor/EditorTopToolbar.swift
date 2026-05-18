@_spi(AdaEngine) import AdaEngine

struct EditorTopToolbar: View {
    let hotReloadState: EditorHotReloadState
    let viewModel: EditorToolbarViewModel
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme
    
    var body: some View {
        ZStack(anchor: .center) {
            SearchBar(
                text: viewModel.searchTextBinding,
                prompt: "Search Everywhere"
            )
            .frame(width: metrics.toolbarSearchWidth)

            HStack(spacing: 12) {
                Spacer(minLength: metrics.toolbarLeadingSpacerWidth)

                if metrics.showsToolbarSceneName {
                    Text(viewModel.sceneName)
                        .font(.system(size: 12))
                        .foregroundColor(theme.editorColors.muted)
                }

                adaEditorToolbarPill(hotReloadState.toolbarTitle, active: hotReloadState.isEnabled && hotReloadState.errorMessage == nil, theme: theme)

                runStopControls
                    .padding(.trailing, 12)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var runStopControls: some View {
        HStack(spacing: 2) {
            toolbarActionButton(title: "Run", symbol: "▶", color: Color(red: 110 / 255, green: 205 / 255, blue: 126 / 255))
            toolbarActionButton(title: "Stop", symbol: "■", color: Color(red: 232 / 255, green: 96 / 255, blue: 96 / 255))
        }
        .padding(4)
        .background {
            RoundedRectangleShape(cornerRadius: 10)
                .fill(theme.editorColors.surface.opacity(0.42))
        }
        .glassEffect(.editorToolbarControls(theme: theme), in: RoundedRectangleShape(cornerRadius: 10))
        .overlay {
            RoundedRectangleShape(cornerRadius: 10)
                .stroke(theme.editorColors.border.opacity(0.72), lineWidth: 1)
        }
    }

    private func toolbarActionButton(title: String, symbol: String, color: Color) -> some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Text(symbol)
                if metrics.showsRunButtonTitle {
                    Text(title)
                }
            }
        }
        .font(.system(size: 12))
        .foregroundColor(color)
        .padding(.horizontal, metrics.showsRunButtonTitle ? 10 : 8)
        .frame(height: 26)
        .background(RoundedRectangleShape(cornerRadius: 7).fill(Color.white.opacity(0.06)))
    }
}

private extension Glass {
    static func editorToolbarControls(theme: Theme) -> Glass {
        var glass = Glass.regular
        glass.blurRadius = 18
        glass.glassTintStrength = 0.52
        glass.edgeShadowStrength = 0
        glass.tintColor = theme.editorColors.surfaceElevated.opacity(0.24)
        return glass
    }
}
