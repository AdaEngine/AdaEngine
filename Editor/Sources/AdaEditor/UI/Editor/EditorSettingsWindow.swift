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
    var codeFontSize: Double
    var codeFontFamily: EditorCodeFontFamily
    var codeFontWeight: EditorCodeFontWeight
    var keywordFontWeight: EditorCodeFontWeight
    var codePalettePreset: EditorCodePalettePreset
    var generalSettingsStatusMessage = ""
    var runtimeDraft: EditorRuntimeSettingsDraft
    var runtimeSettings: AdaProjectRuntime
    var runtimeSettingsStatusMessage = ""

    init(editorViewModel: EditorViewModel?, selectedSection: EditorSettingsSection) {
        let runtimeSettings = Self.loadRuntimeSettings(from: editorViewModel)
        self.editorViewModel = editorViewModel
        self.selectedSection = selectedSection
        self.codeFontSize = editorViewModel?.workbench.codeFontSize ?? 12
        self.codeFontFamily = editorViewModel?.workbench.codeFontFamily ?? .firaCode
        self.codeFontWeight = editorViewModel?.workbench.codeFontWeight ?? .medium
        self.keywordFontWeight = editorViewModel?.workbench.keywordFontWeight ?? .bold
        self.codePalettePreset = EditorCodePalettePreset.matching(editorViewModel?.workbench.codeColorPalette ?? .dark)
        self.runtimeSettings = runtimeSettings
        self.runtimeDraft = EditorRuntimeSettingsDraft(runtime: runtimeSettings)
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
        if let workbench = editorViewModel?.workbench {
            codeFontSize = workbench.codeFontSize
            codeFontFamily = workbench.codeFontFamily
            codeFontWeight = workbench.codeFontWeight
            keywordFontWeight = workbench.keywordFontWeight
            codePalettePreset = EditorCodePalettePreset.matching(workbench.codeColorPalette)
        }
        runtimeSettings = Self.loadRuntimeSettings(from: editorViewModel)
        runtimeDraft = EditorRuntimeSettingsDraft(runtime: runtimeSettings)
        generalSettingsStatusMessage = ""
        runtimeSettingsStatusMessage = ""
    }

    func selectCodeFontFamily(_ family: EditorCodeFontFamily) {
        codeFontFamily = family
        generalSettingsStatusMessage = ""
    }

    func increaseCodeFontSize() {
        codeFontSize = min(codeFontSize + 1, 28)
        generalSettingsStatusMessage = ""
    }

    func decreaseCodeFontSize() {
        codeFontSize = max(codeFontSize - 1, 8)
        generalSettingsStatusMessage = ""
    }

    func resetCodeFontSize() {
        codeFontSize = 12
        generalSettingsStatusMessage = ""
    }

    func selectCodeFontWeight(_ weight: EditorCodeFontWeight) {
        codeFontWeight = weight
        generalSettingsStatusMessage = ""
    }

    func selectKeywordFontWeight(_ weight: EditorCodeFontWeight) {
        keywordFontWeight = weight
        generalSettingsStatusMessage = ""
    }

    func selectCodePalette(_ preset: EditorCodePalettePreset) {
        codePalettePreset = preset
        generalSettingsStatusMessage = ""
    }

    func applyGeneralSettings() {
        guard let workbench = editorViewModel?.workbench else {
            return
        }
        workbench.codeFontSize = codeFontSize
        workbench.codeFontFamily = codeFontFamily
        workbench.codeFontWeight = codeFontWeight
        workbench.keywordFontWeight = keywordFontWeight
        workbench.codeColorPalette = codePalettePreset.palette
        generalSettingsStatusMessage = "Applied to open editors"
    }

    var isAdaScriptProject: Bool {
        editorViewModel?.projectURL.flatMap {
            try? ProjectSystem.loadProject(at: $0).build.system.isAdaScript
        } ?? false
    }

    func runtimeTextBinding(_ keyPath: WritableKeyPath<EditorRuntimeSettingsDraft, String>) -> Binding<String> {
        Binding(
            get: { self.runtimeDraft[keyPath: keyPath] },
            set: {
                self.runtimeDraft[keyPath: keyPath] = $0
                self.runtimeSettingsStatusMessage = ""
            }
        )
    }

    func selectRuntimePreset(_ preset: AdaProjectRuntimePluginPreset) {
        var plugins = runtimeSettings.plugins
        plugins.preset = preset
        plugins.enable = []
        plugins.disable = []
        do {
            _ = try EditorAdaScriptRuntimePluginResolver.resolve(plugins)
            runtimeSettings.plugins = plugins
            runtimeSettingsStatusMessage = ""
        } catch {
            runtimeSettingsStatusMessage = error.localizedDescription
        }
    }

    func isRuntimePluginEnabled(_ pluginID: AdaProjectRuntimePluginID) -> Bool {
        (try? EditorAdaScriptRuntimePluginResolver.resolve(runtimeSettings.plugins))?.contains(pluginID) == true
    }

    func toggleRuntimePlugin(_ pluginID: AdaProjectRuntimePluginID) {
        var plugins = runtimeSettings.plugins
        if isRuntimePluginEnabled(pluginID) {
            plugins.enable.removeAll { $0 == pluginID }
            if !plugins.disable.contains(pluginID) {
                plugins.disable.append(pluginID)
            }
        } else {
            plugins.disable.removeAll { $0 == pluginID }
            if !plugins.enable.contains(pluginID) {
                plugins.enable.append(pluginID)
            }
        }
        plugins.enable.sort { $0.rawValue < $1.rawValue }
        plugins.disable.sort { $0.rawValue < $1.rawValue }
        do {
            _ = try EditorAdaScriptRuntimePluginResolver.resolve(plugins)
            runtimeSettings.plugins = plugins
            runtimeSettingsStatusMessage = ""
        } catch {
            runtimeSettingsStatusMessage = error.localizedDescription
        }
    }

    func toggleRuntimeWindowResizable() {
        runtimeDraft.windowIsResizable.toggle()
        runtimeSettingsStatusMessage = ""
    }

    func saveProjectSettings() {
        guard let editorViewModel else {
            return
        }
        do {
            runtimeSettings = try runtimeDraft.applying(to: runtimeSettings)
            _ = try EditorAdaScriptRuntimePluginResolver.resolve(runtimeSettings.plugins)
            editorViewModel.saveProjectSettings(runtime: runtimeSettings)
            runtimeSettingsStatusMessage = editorViewModel.projectSettingsStatusMessage
        } catch {
            runtimeSettingsStatusMessage = error.localizedDescription
        }
    }

    private static func loadRuntimeSettings(from editorViewModel: EditorViewModel?) -> AdaProjectRuntime {
        guard let projectURL = editorViewModel?.projectURL,
              let project = try? ProjectSystem.loadProject(at: projectURL) else {
            return AdaProjectRuntime()
        }
        return project.runtime
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
            .frame(minWidth: 0, maxWidth: .infinity)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Text(viewModel.selectedSection.title)
                    .font(.system(size: 24))
                    .foregroundColor(theme.editorColors.text)
                    .lineLimit(1)
                Spacer()
                Text(viewModel.projectName)
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(
                        RoundedRectangleShape(cornerRadius: 5)
                            .fill(theme.editorColors.surface)
                    )
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 24)

            ScrollView(.vertical) {
                selectedSectionContent
                    .padding(.horizontal, 34)
                    .padding(.bottom, 24)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
            }

            if viewModel.editorViewModel != nil {
                settingsFooter
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(theme.editorColors.background)
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        if let editorViewModel = viewModel.editorViewModel {
            switch viewModel.selectedSection {
            case .general:
                generalSettings
            case .project:
                projectSettings(editorViewModel)
            case .agent:
                agentSettings(editorViewModel)
            }
        } else {
            emptyProjectSettings
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("EDITOR FONT") {
                settingsRow(
                    title: "Font Family",
                    detail: "Typeface used by source and scene editors."
                ) {
                    HStack(spacing: 6) {
                        ForEach(EditorCodeFontFamily.allCases, id: \.self) { family in
                            selectionButton(family.title, selected: viewModel.codeFontFamily == family) {
                                viewModel.selectCodeFontFamily(family)
                            }
                        }
                    }
                }
                settingsRow(
                    title: "Base Weight",
                    detail: "Default weight for code text."
                ) {
                    HStack(spacing: 6) {
                        ForEach(EditorCodeFontWeight.allCases, id: \.self) { weight in
                            selectionButton(weight.title, selected: viewModel.codeFontWeight == weight) {
                                viewModel.selectCodeFontWeight(weight)
                            }
                        }
                    }
                }
                settingsRow(
                    title: "Code Font Size",
                    detail: "Controls the font size used by source editors."
                ) {
                    HStack(spacing: 6) {
                        compactButton("−", action: viewModel.decreaseCodeFontSize)
                        Text("\(Int(viewModel.codeFontSize)) pt")
                            .font(.system(size: 11))
                            .foregroundColor(theme.editorColors.text)
                            .frame(width: 48)
                        compactButton("+", action: viewModel.increaseCodeFontSize)
                        compactButton("Reset", action: viewModel.resetCodeFontSize)
                    }
                }
            }
            settingsGroup("SYNTAX APPEARANCE") {
                settingsRow(
                    title: "Color Palette",
                    detail: "Colors used for syntax categories."
                ) {
                    HStack(spacing: 6) {
                        ForEach(EditorCodePalettePreset.allCases, id: \.self) { preset in
                            paletteButton(preset)
                        }
                    }
                }
                settingsRow(
                    title: "Keyword Font",
                    detail: "Emphasize language keywords and annotations."
                ) {
                    HStack(spacing: 6) {
                        ForEach(EditorCodeFontWeight.allCases, id: \.self) { weight in
                            selectionButton(weight.title, selected: viewModel.keywordFontWeight == weight) {
                                viewModel.selectKeywordFontWeight(weight)
                            }
                        }
                    }
                }
                codeAppearancePreview
            }
        }
    }

    private func projectSettings(_ editorViewModel: EditorViewModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if viewModel.isAdaScriptProject {
                EditorRuntimeProjectSettingsView(
                    projectName: editorViewModel.project?.name ?? "Game",
                    viewModel: viewModel
                )
            }
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
                .lineLimit(1)
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
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(1)
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

    private func paletteButton(_ preset: EditorCodePalettePreset) -> some View {
        let isSelected = viewModel.codePalettePreset == preset
        return Button {
            viewModel.selectCodePalette(preset)
        } label: {
            HStack(spacing: 6) {
                CircleShape()
                    .fill(preset.palette.keyword)
                    .frame(width: 9, height: 9)
                Text(preset.title)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? theme.editorColors.text : theme.editorColors.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangleShape(cornerRadius: 6)
                    .fill(isSelected ? theme.editorColors.blue.opacity(0.22) : theme.editorColors.surface)
            )
        }
        .buttonStyle(DefaultButtonStyle())
    }

    private var codeAppearancePreview: some View {
        let palette = viewModel.codePalettePreset.palette
        let baseFont = AdaEditorCodeFont.font(
            family: viewModel.codeFontFamily,
            weight: viewModel.codeFontWeight,
            size: 13
        )
        let keywordFont = AdaEditorCodeFont.font(
            family: viewModel.codeFontFamily,
            weight: viewModel.keywordFontWeight,
            size: 13
        )
        return HStack(spacing: 0) {
            Text("func ")
                .font(keywordFont)
                .foregroundColor(palette.keyword)
            Text("update")
                .font(baseFont)
                .foregroundColor(palette.type)
            Text("() { ")
                .font(baseFont)
                .foregroundColor(palette.punctuation)
            Text("let ")
                .font(keywordFont)
                .foregroundColor(palette.keyword)
            Text("title = ")
                .font(baseFont)
                .foregroundColor(palette.plainText)
            Text("\"Ada\"")
                .font(baseFont)
                .foregroundColor(palette.string)
            Text(" }")
                .font(baseFont)
                .foregroundColor(palette.punctuation)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 42, maxHeight: 42)
        .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surfaceElevated))
        .overlay {
            RoundedRectangleShape(cornerRadius: 6)
                .stroke(theme.editorColors.border, lineWidth: 1)
        }
    }

    private var settingsFooter: some View {
        let configuration = footerConfiguration
        return VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if !configuration.status.isEmpty {
                    Text(configuration.status)
                        .font(.system(size: 11))
                        .foregroundColor(theme.editorColors.muted)
                        .lineLimit(1)
                }
                Spacer()
                primaryButton(configuration.title, action: configuration.action)
            }
            .padding(.horizontal, 34)
            .frame(height: 64)
            .background(theme.editorColors.surface)
        }
    }

    private var footerConfiguration: (title: String, status: String, action: () -> Void) {
        guard let editorViewModel = viewModel.editorViewModel else {
            return ("Apply", "", {})
        }

        switch viewModel.selectedSection {
        case .general:
            return ("Apply", viewModel.generalSettingsStatusMessage, viewModel.applyGeneralSettings)
        case .project:
            let status = viewModel.runtimeSettingsStatusMessage.isEmpty
                ? editorViewModel.projectSettingsStatusMessage
                : viewModel.runtimeSettingsStatusMessage
            return ("Save Project Settings", status, viewModel.saveProjectSettings)
        case .agent:
            return ("Save Agent Settings", editorViewModel.agent.settingsStatusMessage, editorViewModel.agent.saveAgentSettings)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
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
    }
}
