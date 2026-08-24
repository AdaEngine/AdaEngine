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
                        dependencyRow(dependency)
                    }
                }
                section("ADD PACKAGE") {
                    input("URL or local path", text: viewModel.dependencyLocationBinding)
                    input("Requirement, e.g. from: \"1.0.0\"", text: viewModel.dependencyRequirementBinding)
                    command("Add Dependency") { viewModel.addProjectDependency() }
                    if !viewModel.dependencyStatusMessage.isEmpty {
                        row(viewModel.dependencyStatusMessage)
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
            section("RUN PRODUCTS") {
                ForEach(viewModel.runProducts, id: \.self) { product in
                    command(product) {
                        viewModel.selectedRunProduct = product
                        viewModel.runSelectedTarget()
                    }
                }
            }
        case "projectSettings":
            section("RESOURCE ROOTS") {
                row("Comma or newline separated project-relative folders.")
                input("Assets, Localization", text: viewModel.projectResourceRootsBinding)
            }
            section("BUILD FILE SELECTION") {
                row("Included files/directories")
                input("Sources/Game, Sources/Shared.swift", text: viewModel.projectIncludedFilesBinding)
                row("Excluded files/directories")
                input("Sources/Game/Drafts", text: viewModel.projectExcludedFilesBinding)
            }
            section("RUN DESTINATION") {
                row("Selected in the toolbar: \(viewModel.selectedRunDestination.rawValue)")
            }
            section("SAVE") {
                command("Save Project Settings") { viewModel.saveProjectSettings() }
                if !viewModel.projectSettingsStatusMessage.isEmpty {
                    row(viewModel.projectSettingsStatusMessage)
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

    private func dependencyRow(_ dependency: SwiftPackageDependency) -> some View {
        HStack(spacing: 6) {
            row(dependency.url ?? dependency.path ?? dependency.identity)
            if dependency.identity.lowercased() == "adaengine" {
                Text("Managed")
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.muted)
            } else {
                Button(action: { viewModel.removeProjectDependency(identity: dependency.identity) }) {
                    Text("Remove")
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.blue)
                }
                .buttonStyle(DefaultButtonStyle())
            }
        }
    }

    private func input(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 11))
            .foregroundColor(theme.editorColors.text)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangleShape(cornerRadius: 6)
                    .fill(theme.editorColors.surface)
            )
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
