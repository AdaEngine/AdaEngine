//
//  EditorSettingsWindow.swift
//  AdaEditor
//

@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation

enum EditorSettingsSection: String, CaseIterable, Hashable, Sendable {
    case general
    case project
    case agent

    var title: String {
        switch self {
        case .general:
            "General"
        case .project:
            "Project"
        case .agent:
            "Agent"
        }
    }

    var icon: String {
        switch self {
        case .general:
            "\u{E8B8}"
        case .project:
            "\u{E2C7}"
        case .agent:
            "\u{E7FD}"
        }
    }
}

@Observable
@MainActor
final class EditorSettingsWindowViewModel {
    var selectedSection: EditorSettingsSection
    var searchText = ""
    var editorViewModel: EditorViewModel?

    init(editorViewModel: EditorViewModel?, selectedSection: EditorSettingsSection) {
        self.editorViewModel = editorViewModel
        self.selectedSection = selectedSection
    }

    var searchTextBinding: Binding<String> {
        Binding(get: { self.searchText }, set: { self.searchText = $0 })
    }

    var filteredSections: [EditorSettingsSection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return EditorSettingsSection.allCases
        }
        return EditorSettingsSection.allCases.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var projectName: String {
        editorViewModel?.project?.name ?? "No Project"
    }

    func update(editorViewModel: EditorViewModel?, selectedSection: EditorSettingsSection) {
        self.editorViewModel = editorViewModel
        self.selectedSection = selectedSection
    }
}

@MainActor
enum EditorSettingsWindowController {
    static let windowTitle = "AdaEditor Settings"
    static let windowWidth: Float = 980
    static let windowHeight: Float = 680

    private static weak var settingsWindow: UIWindow?
    private static var settingsViewModel: EditorSettingsWindowViewModel?

    static func open(
        editorViewModel: EditorViewModel? = nil,
        project: EditorProjectReference? = nil,
        selectedSection: EditorSettingsSection = .general
    ) {
        guard let windowManager = UIWindowManager.shared else {
            return
        }

        let resolvedEditorViewModel: EditorViewModel?
        if let editorViewModel {
            resolvedEditorViewModel = editorViewModel
        } else if let project,
                  let existingEditorViewModel = settingsViewModel?.editorViewModel,
                  existingEditorViewModel.project?.path == project.path {
            resolvedEditorViewModel = existingEditorViewModel
        } else {
            resolvedEditorViewModel = project.map { EditorViewModel(project: $0) }
        }

        if let settingsWindow,
           windowManager.windows[settingsWindow.id] != nil,
           let settingsViewModel {
            settingsViewModel.update(editorViewModel: resolvedEditorViewModel, selectedSection: selectedSection)
            settingsWindow.showWindow(makeFocused: true)
            return
        }

        let viewModel = EditorSettingsWindowViewModel(
            editorViewModel: resolvedEditorViewModel,
            selectedSection: selectedSection
        )
        let configuration = UIWindow.Configuration(
            title: windowTitle,
            frame: Rect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            minimumSize: Size(width: 760, height: 520),
            mode: .windowed,
            chrome: .standard,
            titleBar: .standard,
            background: .opaque(EditorThemeColors.dark.background),
            showsImmediately: false,
            makeKey: true,
            hasShadow: true,
            isResizable: true
        )
        let window = windowManager.spawnWindow(configuration: configuration) {
            EditorSettingsWindowView(viewModel: viewModel)
                .theme(.adaEditor)
        }
        settingsViewModel = viewModel
        settingsWindow = window
        window.showWindow(makeFocused: true)
    }
}

struct EditorSettingsWindowView: View {
    static let accessibilityIdentifier = "AdaEditor.Settings.Window"

    let viewModel: EditorSettingsWindowViewModel

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            theme.editorColors.border
                .frame(width: 1)
                .frame(maxHeight: .infinity)
            content
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(theme.editorColors.background)
        .foregroundColor(theme.editorColors.text)
        .accessibilityIdentifier(Self.accessibilityIdentifier)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 20))
                .foregroundColor(theme.editorColors.text)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 14)

            HStack(spacing: 8) {
                Text("\u{E8B6}")
                    .font(AdaEditorMaterialSymbolFont.font(size: 16))
                    .foregroundColor(theme.editorColors.muted)
                TextField("Search settings…", text: viewModel.searchTextBinding)
                    .font(.system(size: 12))
                    .foregroundColor(theme.editorColors.text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .accessibilityIdentifier("AdaEditor.Settings.Search")
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(
                RoundedRectangleShape(cornerRadius: 7)
                    .fill(theme.editorColors.background)
            )
            .overlay {
                RoundedRectangleShape(cornerRadius: 7)
                    .stroke(theme.editorColors.border, lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(viewModel.filteredSections, id: \.self) { section in
                    sectionButton(section)
                }

                if viewModel.filteredSections.isEmpty {
                    Text("No matching settings")
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.muted)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text("CURRENT PROJECT")
                    .font(.system(size: 9))
                    .foregroundColor(theme.editorColors.muted)
                Text(viewModel.projectName)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.text)
                    .lineLimit(1)
            }
            .padding(16)
        }
        .frame(width: 236)
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.editorColors.surface)
    }

    private func sectionButton(_ section: EditorSettingsSection) -> some View {
        let isSelected = viewModel.selectedSection == section
        return Button {
            viewModel.selectedSection = section
        } label: {
            HStack(spacing: 9) {
                Text(section.icon)
                    .font(AdaEditorMaterialSymbolFont.font(size: 17))
                    .foregroundColor(isSelected ? theme.editorColors.blue : theme.editorColors.muted)
                Text(section.title)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? theme.editorColors.text : theme.editorColors.muted)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(
                RoundedRectangleShape(cornerRadius: 6)
                    .fill(isSelected ? theme.editorColors.blue.opacity(0.18) : Color.clear)
            )
        }
        .buttonStyle(DefaultButtonStyle())
        .padding(.horizontal, 8)
        .accessibilityIdentifier("AdaEditor.Settings.Section.\(section.title)")
    }

    private var content: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    Text(viewModel.selectedSection.title)
                        .font(.system(size: 24))
                        .foregroundColor(theme.editorColors.text)
                    Spacer()
                    Text(viewModel.projectName)
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.muted)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(
                            RoundedRectangleShape(cornerRadius: 5)
                                .fill(theme.editorColors.surface)
                        )
                }
                .padding(.bottom, 22)

                selectedSectionContent
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(theme.editorColors.background)
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        if let editorViewModel = viewModel.editorViewModel {
            switch viewModel.selectedSection {
            case .general:
                generalSettings(editorViewModel)
            case .project:
                projectSettings(editorViewModel)
            case .agent:
                agentSettings(editorViewModel)
            }
        } else {
            emptyProjectSettings
        }
    }

    private func generalSettings(_ editorViewModel: EditorViewModel) -> some View {
        settingsGroup("EDITOR") {
            settingsRow(
                title: "Code Font Size",
                detail: "Controls the font size used by source editors."
            ) {
                HStack(spacing: 6) {
                    compactButton("−") { editorViewModel.workbench.decreaseCodeFontSize() }
                    Text("\(Int(editorViewModel.workbench.codeFontSize)) pt")
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.text)
                        .frame(width: 48)
                    compactButton("+") { editorViewModel.workbench.increaseCodeFontSize() }
                    compactButton("Reset") { editorViewModel.workbench.resetCodeFontSize() }
                }
            }
        }
    }

    private func projectSettings(_ editorViewModel: EditorViewModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("RESOURCE ROOTS") {
                settingsField(
                    "Assets, Localization",
                    detail: "Comma or newline separated project-relative folders.",
                    text: editorViewModel.projectResourceRootsBinding
                )
            }
            settingsGroup("BUILD FILE SELECTION") {
                settingsField(
                    "Sources/Game, Sources/Shared.swift",
                    detail: "Included files and directories.",
                    text: editorViewModel.projectIncludedFilesBinding
                )
                settingsField(
                    "Sources/Game/Drafts",
                    detail: "Excluded files and directories.",
                    text: editorViewModel.projectExcludedFilesBinding
                )
            }
            settingsGroup("RUN DESTINATION") {
                HStack(spacing: 8) {
                    ForEach(EditorRunDestination.allCases, id: \.self) { destination in
                        selectionButton(destination.rawValue, selected: editorViewModel.selectedRunDestination == destination) {
                            editorViewModel.selectRunDestination(destination)
                        }
                    }
                }
            }
            saveSection(
                title: "Save Project Settings",
                status: editorViewModel.projectSettingsStatusMessage,
                action: editorViewModel.saveProjectSettings
            )
        }
    }

    private func agentSettings(_ editorViewModel: EditorViewModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("ACP CONNECTION") {
                Text("Configure the stdio ACP agent launched for this project.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                selectionButton(
                    editorViewModel.agent.agentEnabled ? "Enabled" : "Disabled",
                    selected: editorViewModel.agent.agentEnabled,
                    action: editorViewModel.agent.toggleAgentEnabled
                )
                settingsInput("Agent executable, e.g. codex-acp", text: editorViewModel.agent.agentCommandBinding)
                settingsInput("Arguments, comma separated", text: editorViewModel.agent.agentArgumentsBinding)
                settingsInput("Working directory (project relative)", text: editorViewModel.agent.agentWorkingDirectoryBinding)
                settingsInput("Environment KEY=VALUE, comma separated", text: editorViewModel.agent.agentEnvironmentBinding)
            }
            settingsGroup("PERMISSIONS") {
                HStack(spacing: 8) {
                    selectionButton("Allow once", selected: editorViewModel.agent.agentPermissionMode == .allowOnce) {
                        editorViewModel.agent.selectPermissionMode(.allowOnce)
                    }
                    selectionButton("Deny", selected: editorViewModel.agent.agentPermissionMode == .deny) {
                        editorViewModel.agent.selectPermissionMode(.deny)
                    }
                }
                Text("File access is restricted to the project root. Terminal working directories are validated against it.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(2)
            }
            settingsGroup("CONTEXT") {
                settingsInput("Skill folders, comma separated", text: editorViewModel.agent.agentSkillsDirectoriesBinding)
                Text("Live scene, entity, asset, render and UI inspection is provided through the embedded AdaEditor Runtime MCP server.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(3)
            }
            saveSection(
                title: "Save Agent Settings",
                status: editorViewModel.agent.settingsStatusMessage,
                action: editorViewModel.agent.saveAgentSettings
            )
        }
    }

    private var emptyProjectSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open or select a project to edit its settings.")
                .font(.system(size: 14))
                .foregroundColor(theme.editorColors.text)
            Text("General editor preferences will become available in an editor window.")
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
        }
        .padding(18)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangleShape(cornerRadius: 8)
                .fill(theme.editorColors.surfaceElevated)
        )
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.blue)
            Divider()
            content()
        }
    }

    private func settingsRow<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder control: @escaping () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(theme.editorColors.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
            }
            Spacer()
            control()
        }
        .padding(.vertical, 8)
    }

    private func settingsField(_ placeholder: String, detail: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            settingsInput(placeholder, text: text)
        }
    }

    private func settingsInput(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 12))
            .foregroundColor(theme.editorColors.text)
            .padding(.horizontal, 10)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 34, maxHeight: 34)
            .background(
                RoundedRectangleShape(cornerRadius: 6)
                    .fill(theme.editorColors.surface)
            )
            .overlay {
                RoundedRectangleShape(cornerRadius: 6)
                    .stroke(theme.editorColors.border, lineWidth: 1)
            }
            .textFieldStyle(PlainTextFieldStyle())
    }

    private func selectionButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(selected ? theme.editorColors.text : theme.editorColors.muted)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    RoundedRectangleShape(cornerRadius: 6)
                        .fill(selected ? theme.editorColors.blue.opacity(0.22) : theme.editorColors.surface)
                )
        }
        .buttonStyle(DefaultButtonStyle())
    }

    private func compactButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.text)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(
                    RoundedRectangleShape(cornerRadius: 5)
                        .fill(theme.editorColors.surface)
                )
        }
        .buttonStyle(DefaultButtonStyle())
    }

    private func saveSection(title: String, status: String, action: @escaping () -> Void) -> some View {
        settingsGroup("SAVE") {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(
                        RoundedRectangleShape(cornerRadius: 6)
                            .fill(theme.editorColors.blue)
                    )
            }
            .buttonStyle(DefaultButtonStyle())

            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(3)
            }
        }
    }
}
