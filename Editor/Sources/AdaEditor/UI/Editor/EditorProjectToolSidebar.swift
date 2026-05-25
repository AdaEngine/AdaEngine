@_spi(AdaEngine) import AdaEngine

struct EditorProjectToolSidebar: View {
    let viewModel: EditorViewModel

    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            adaEditorPanelTitle(title, trailing: viewModel.workspaceStatus.title, theme: theme)
            content
            Spacer()
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
    }

    private var title: String {
        switch viewModel.toolStrip.activeRightTool {
        case "projectDependencies":
            "DEPENDENCIES"
        case "swiftPackageTasks":
            "SWIFT PACKAGE"
        default:
            "PROJECT"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.toolStrip.activeRightTool {
        case "projectDependencies":
            if let packageModel = viewModel.packageModel {
                section("PRODUCTS") {
                    ForEach(packageModel.products, id: \.name) { product in
                        row("\(product.name) · \(product.type)")
                    }
                }
                section("DEPENDENCIES") {
                    ForEach(packageModel.dependencies, id: \.identity) { dependency in
                        row(dependency.url ?? dependency.path ?? dependency.identity)
                    }
                }
                section("PLUGINS") {
                    ForEach(packageModel.pluginTargets, id: \.self) { plugin in
                        row(plugin)
                    }
                }
            } else {
                section("PACKAGE") {
                    row("Package model is not loaded yet.")
                }
            }
        case "swiftPackageTasks":
            section("COMMANDS") {
                command("Resolve Dependencies") { viewModel.bootstrapWorkspaceIfNeeded(force: true) }
                command("Build All") { viewModel.buildAll() }
                command("Run Selected") { viewModel.runSelectedTarget() }
                command("Run Tests") { viewModel.runTests() }
                command("Update Dependencies") { viewModel.updateDependencies() }
                command("Clean Build Artifacts") { viewModel.cleanPackageCache() }
                command("Reset Package Cache") { viewModel.resetPackageCache() }
            }
            section("RUN TARGETS") {
                ForEach(viewModel.runTargets, id: \.self) { target in
                    command(target) {
                        viewModel.selectedRunTarget = target
                        viewModel.runSelectedTarget()
                    }
                }
            }
        default:
            section("STATUS") {
                row(viewModel.workspaceStatus.title)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.blue)
            content()
        }
        .padding(12)
    }

    private func row(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(theme.editorColors.muted)
            .lineLimit(2)
            .lineBreakMode(.byCharWrapping)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private func command(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.blue)
                .frame(height: 24, alignment: .leading)
        }
        .buttonStyle(DefaultButtonStyle())
    }
}
