@_spi(AdaEngine) import AdaEngine

struct EditorTopToolbar: View {
    let hotReloadState: EditorHotReloadState
    let viewModel: EditorToolbarViewModel
    let isRunEnabled: Bool
    let isStopEnabled: Bool
    let onRun: () -> Void
    let onStop: () -> Void
    
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme
    
    var body: some View {
        ZStack(anchor: .center) {
            SearchBar(
                text: viewModel.searchTextBinding,
                prompt: "Search Everywhere",
                width: metrics.toolbarSearchWidth
            )
            .searchBarStyle(EditorToolbarSearchBarStyle(theme: theme))

            HStack(spacing: 12) {
                if metrics.showsToolbarSceneName {
                    Text(viewModel.sceneName)
                        .font(.system(size: 12))
                        .foregroundColor(theme.editorColors.muted)
                }

                adaEditorToolbarPill(hotReloadState.toolbarTitle, active: hotReloadState.isEnabled && hotReloadState.errorMessage == nil, theme: theme)

                runStopControls
            }
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    private var runStopControls: some View {
        HStack(spacing: 2) {
            toolbarActionButton(title: "Run", symbol: "▶", color: Color(red: 110 / 255, green: 205 / 255, blue: 126 / 255), action: onRun)
                .disabled(!isRunEnabled)
                .opacity(isRunEnabled ? 1 : 0.45)
            toolbarActionButton(title: "Stop", symbol: "■", color: Color(red: 232 / 255, green: 96 / 255, blue: 96 / 255), action: onStop)
                .disabled(!isStopEnabled)
                .opacity(isStopEnabled ? 1 : 0.45)
        }
        .padding(4)
        .glassEffect(.editorToolbarControls(theme: theme), in: RoundedRectangleShape(cornerRadius: 10))
    }

    private func toolbarActionButton(title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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

private struct EditorToolbarSearchBarStyle: SearchBarStyle {
    let theme: Theme

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\u{E8B6}")
                .font(AdaEditorMaterialSymbolFont.font(size: 17))
                .foregroundColor(theme.editorColors.text.opacity(0.88))
                .frame(width: 18, height: 18)

            configuration.label
                .foregroundColor(theme.editorColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !configuration.isEmpty {
                Button(action: configuration.clear) {
                    Text("\u{E5CD}")
                        .font(AdaEditorMaterialSymbolFont.font(size: 16))
                        .foregroundColor(theme.editorColors.text.opacity(0.86))
                }
                .accessibilityIdentifier("AdaUI.SearchBar.clearButton")
                .buttonStyle(EditorToolbarSearchBarClearButtonStyle(theme: theme))
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.editorToolbarSearch(theme: theme), in: CapsuleShape())
    }
}

private struct EditorToolbarSearchBarClearButtonStyle: ButtonStyle {
    let theme: Theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 24, height: 24)
            .background {
                CircleShape().fill(configuration.state.isHighlighted ? theme.editorColors.surface.opacity(0.72) : .clear)
            }
            .opacity(configuration.state.isHighlighted ? 0.72 : 1.0)
    }
}

private extension Glass {
    static func editorToolbarSearch(theme: Theme) -> Glass {
        var glass = Glass.regular
        glass.blurRadius = 18
        glass.glassTintStrength = 0.52
        glass.edgeShadowStrength = 0
        glass.tintColor = theme.editorColors.surface.opacity(0.46)
        return glass
    }
}
