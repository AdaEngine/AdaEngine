@_spi(AdaEngine) import AdaEngine

struct EditorAgentSidebar: View {
    let viewModel: EditorAgentViewModel
    var onOpenCatalog: (() -> Void)?

    @State private var composerHeight: Float = 104
    @State private var composerDragStart: Float?
    @State private var showsSkillPicker = false
    @State private var skillSearchText = ""
    @State private var showsContextPicker = false
    @State private var contextSearchText = ""
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            agentHeader
            conversationToolbar
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            composer
        }
        .background(
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        )
        .mask(RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner))
    }

    private var agentHeader: some View {
        HStack(spacing: 8) {
            Text(viewModel.projectName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(theme.editorColors.text)
                .lineLimit(1)
            Spacer()
            if let onOpenCatalog {
                Button("Agents", action: onOpenCatalog)
                    .font(.system(size: 11))
                    .accessibilityIdentifier("AdaEditor.Agent.OpenCatalog")
            }
            Text(viewModel.connectionState.title)
                .font(.system(size: 9))
                .foregroundColor(theme.editorColors.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(theme.editorColors.background)
        .accessibilityIdentifier("AdaEditor.Agent.Header")
    }

    private var conversationToolbar: some View {
        HStack(spacing: 6) {
            Text("\u{E0CA}")
                .font(AdaEditorMaterialSymbolFont.font(size: 17))
                .foregroundColor(theme.editorColors.muted)
                .frame(width: 26, height: 30)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(viewModel.sessions, id: \.id) { session in
                        sessionButton(session)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            toolbarButton(symbol: "\u{E8B8}", title: "Connect", action: viewModel.connect)
            toolbarButton(symbol: "\u{E872}", title: "Delete session", action: viewModel.deleteActiveSession)
            Button(action: {
                Task {
                    try? await viewModel.createSession()
                }
            }) {
                Text("+")
                    .font(.system(size: 18))
                    .foregroundColor(theme.editorColors.text)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(DefaultButtonStyle())
        }
        .padding(.horizontal, 8)
        .frame(height: 42)
        .background(theme.editorColors.surface)
        .overlay {
            VStack(spacing: 0) {
                Spacer()
                RectangleShape().fill(theme.editorColors.border.opacity(0.55)).frame(height: 1)
            }
        }
        .accessibilityIdentifier("AdaEditor.Agent.ConversationToolbar")
    }

    private func toolbarButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(AdaEditorMaterialSymbolFont.font(size: 16))
                .foregroundColor(theme.editorColors.muted)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(DefaultButtonStyle())
        .accessibilityIdentifier("AdaEditor.Agent.\(title)")
    }

    private func sessionButton(_ session: EditorAgentSessionSummary) -> some View {
        let active = session.id == viewModel.activeSession?.id
        return Button(action: { viewModel.selectSession(session) }) {
            Text(session.title)
                .font(.system(size: 11, weight: active ? .bold : .regular))
                .foregroundColor(active ? theme.editorColors.text : theme.editorColors.muted)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(height: 30)
        }
        .buttonStyle(DefaultButtonStyle())
    }

    private var configurationControls: some View {
        HStack(spacing: 4) {
            if !viewModel.sessionConfiguration.selectors.contains(where: { $0.category == .mode }) {
                configurationLabel(viewModel.mode.title)
                    .contextMenu(opensOnPrimaryAction: true) {
                        ForEach(EditorAgentChatMode.allCases, id: \.self) { mode in
                            Button(mode.title) { viewModel.mode = mode }
                        }
                    }
            }
            ForEach(viewModel.sessionConfiguration.selectors.filter { $0.category != .other }, id: \.id) { selector in
                configurationLabel(selectedChoiceName(in: selector))
                    .contextMenu(opensOnPrimaryAction: true) {
                        ForEach(selector.choices, id: \.id) { choice in
                            ContextMenuOption(choice.name, isSelected: choice.id == selector.currentValueID) {
                                viewModel.selectConfiguration(selectorID: selector.id, valueID: choice.id)
                            }
                        }
                    }
                    .disabled(viewModel.isSending)
                    .accessibilityIdentifier("AdaEditor.Agent.Selector.\(selector.category.rawValue)")
            }
            if !viewModel.sessionConfiguration.selectors.contains(where: { $0.category == .model }) {
                fallbackModelSelector
                    .accessibilityIdentifier("AdaEditor.Agent.Selector.model")
            }
        }
    }

    @ViewBuilder
    private var fallbackModelSelector: some View {
        switch viewModel.connectionState {
        case .ready, .running:
            Text("Agent default")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.editorColors.muted)
                .padding(.horizontal, 7)
                .frame(height: 30)
        case .connecting:
            Text("Loading models…")
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
        case .disconnected, .failed:
            Button(action: viewModel.connect) {
                configurationLabel("Select model")
            }
            .buttonStyle(DefaultButtonStyle())
            .disabled(viewModel.isSending)
        }
    }

    private func configurationLabel(_ title: String) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            Text("\u{E5CF}")
                .font(AdaEditorMaterialSymbolFont.font(size: 15))
        }
        .foregroundColor(theme.editorColors.text)
        .padding(.horizontal, 7)
        .frame(height: 30)
        .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surface))
    }

    private func selectedChoiceName(in selector: EditorAgentConfigurationSelector) -> String {
        selector.choices.first { $0.id == selector.currentValueID }?.name ?? selector.name
    }

    private var transcript: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let session = viewModel.activeSession, !session.events.isEmpty {
                    ForEach(session.events, id: \.id) { event in
                        eventRow(event)
                    }
                } else {
                    emptyState
                }
            }
            .padding(10)
        }
    }

    private func eventRow(_ event: EditorAgentEvent) -> some View {
        EditorAgentEventCard(event: event, viewModel: viewModel)
    }

    @ViewBuilder
    private var contextPicker: some View {
        if showsContextPicker {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Search project files", text: Binding(get: { contextSearchText }, set: { contextSearchText = $0 }))
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.text)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.background))
                    .textFieldStyle(PlainTextFieldStyle())
                    .accessibilityIdentifier("AdaEditor.Agent.ContextSearch")
                Button(action: { viewModel.presentContextFilePicker() }) {
                    Text("Browse files and images…")
                        .font(.system(size: 10))
                        .foregroundColor(theme.editorColors.blue)
                        .frame(height: 24)
                }
                .buttonStyle(DefaultButtonStyle())
                .accessibilityIdentifier("AdaEditor.Agent.BrowseContext")
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.contextFiles(matching: contextSearchText), id: \.id) { entry in
                            Button(action: { viewModel.attachProjectFile(entry) }) {
                                HStack(spacing: 6) {
                                    Text(contextFileLabel(entry.path))
                                        .font(.system(size: 9))
                                        .foregroundColor(theme.editorColors.blue)
                                        .frame(width: 28)
                                    Text(entry.path)
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.editorColors.text)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 5)
                                .frame(height: 24)
                            }
                            .buttonStyle(DefaultButtonStyle())
                        }
                    }
                }
                .frame(height: 150)
            }
            .padding(6)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surfaceElevated))
            .overlay {
                RoundedRectangleShape(cornerRadius: 6)
                    .stroke(theme.editorColors.border.opacity(0.45), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var pendingAttachmentList: some View {
        if !viewModel.pendingAttachments.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(viewModel.pendingAttachments, id: \.id) { attachment in
                        EditorAgentAttachmentCard(attachment: attachment) {
                            viewModel.removeAttachment(id: attachment.id)
                        }
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 0) {
            sceneContextIndicator
            codeSelectionIndicator
            contextPicker
            pendingAttachmentList
            skillPicker
            autocompleteList
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangleShape(cornerRadius: 2)
                        .fill(theme.editorColors.muted.opacity(0.6))
                        .frame(width: 28, height: 3)
                    EditorResizeHandle(axis: .vertical) { translation in
                        let start = composerDragStart ?? composerHeight
                        composerDragStart = start
                        composerHeight = min(320, max(64, start - translation.height))
                    } onResizeEnded: {
                        composerDragStart = nil
                    }
                }
                .frame(height: 10)
                .accessibilityIdentifier("AdaEditor.Agent.ResizeComposer")

                TextEditor(
                    "Ask the agent. Use @ to attach files.",
                    text: viewModel.promptBinding,
                    showsLineNumbers: false
                )
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.text)
                .frame(height: composerHeight)
                .frame(minWidth: 0, maxWidth: .infinity)
                .textEditorColors(composerTextEditorColors)
                .accessibilityIdentifier("AdaEditor.Agent.Prompt")

                HStack(spacing: 4) {
                    compactComposerButton("+", active: showsContextPicker) {
                        showsContextPicker.toggle()
                    }
                    .accessibilityIdentifier("AdaEditor.Agent.AddContext")
                    if !viewModel.availableSkills.isEmpty {
                        compactComposerButton(
                            viewModel.selectedSkillIDs.isEmpty ? "Skills" : "Skills \(viewModel.selectedSkillIDs.count)",
                            active: showsSkillPicker
                        ) {
                            showsSkillPicker.toggle()
                        }
                        .accessibilityIdentifier("AdaEditor.Agent.Skills")
                    }
                    configurationControls
                    Spacer()
                    if viewModel.isSending {
                        Button(action: { viewModel.interrupt() }) {
                            Text("\u{E047}")
                                .font(AdaEditorMaterialSymbolFont.font(size: 20))
                                .foregroundColor(theme.editorColors.muted)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(DefaultButtonStyle())
                    }
                    Button(action: { viewModel.sendPrompt() }) {
                        Text("\u{E5D8}")
                            .font(AdaEditorMaterialSymbolFont.font(size: 22))
                            .foregroundColor(theme.editorColors.background)
                            .frame(width: 34, height: 34)
                            .background(CircleShape().fill(theme.editorColors.text.opacity(viewModel.canSend ? 1 : 0.28)))
                    }
                    .buttonStyle(DefaultButtonStyle())
                    .disabled(!viewModel.canSend)
                    .accessibilityIdentifier("AdaEditor.Agent.Send")
                }
            }
            .padding(8)
            .background(RoundedRectangleShape(cornerRadius: 10).fill(theme.editorColors.surfaceElevated))
            .overlay {
                RoundedRectangleShape(cornerRadius: 10)
                    .stroke(theme.editorColors.border.opacity(0.8), lineWidth: 1)
            }
            .accessibilityIdentifier("AdaEditor.Agent.Composer")
        }
        .padding(8)
        .background(theme.editorColors.surface)
    }

    private var composerTextEditorColors: TextEditorColors {
        TextEditorColors(
            background: theme.editorColors.surfaceElevated,
            border: Color.clear,
            focusedBorder: Color.clear,
            gutter: Color.clear,
            gutterRule: Color.clear,
            currentLineBackground: Color.clear,
            selection: theme.editorColors.blue.opacity(0.24)
        )
    }

    private func compactComposerButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: title == "+" ? 20 : 11, weight: .semibold))
                .foregroundColor(theme.editorColors.text)
                .padding(.horizontal, title == "+" ? 5 : 7)
                .frame(height: 30)
                .background(RoundedRectangleShape(cornerRadius: 6).fill(active ? theme.editorColors.blue.opacity(0.20) : theme.editorColors.surface))
        }
        .buttonStyle(DefaultButtonStyle())
    }

    @ViewBuilder
    private var codeSelectionIndicator: some View {
        if let context = viewModel.codeSelection {
            VStack(alignment: .leading, spacing: 3) {
                Text("Selected code · \(context.lineDescription)")
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.text)
                Text(context.documentRelativePath)
                    .font(.system(size: 9))
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.purple.opacity(0.10)))
            .overlay {
                RoundedRectangleShape(cornerRadius: 6)
                    .stroke(theme.editorColors.purple.opacity(0.24), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var sceneContextIndicator: some View {
        if let context = viewModel.sceneContext {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(context.sceneTitle) · \(context.selectedEntityName)")
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.text)
                    .lineLimit(1)
                Text(context.sceneRelativePath)
                    .font(.system(size: 9))
                    .foregroundColor(theme.editorColors.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.blue.opacity(0.10)))
            .overlay {
                RoundedRectangleShape(cornerRadius: 6)
                    .stroke(theme.editorColors.blue.opacity(0.24), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var skillPicker: some View {
        if showsSkillPicker {
            VStack(alignment: .leading, spacing: 6) {
                TextField("Search skills", text: Binding(get: { skillSearchText }, set: { skillSearchText = $0 }))
                    .font(.system(size: 10))
                    .foregroundColor(theme.editorColors.text)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.background))
                    .textFieldStyle(PlainTextFieldStyle())
                    .accessibilityIdentifier("AdaEditor.Agent.SkillSearch")

                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(filteredSkills, id: \.id) { skill in
                            Button(action: { viewModel.toggleSkill(skill) }) {
                                HStack(spacing: 6) {
                                    Text(viewModel.selectedSkillIDs.contains(skill.id) ? "✓" : "")
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.editorColors.blue)
                                        .frame(width: 12)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("/\(skill.id)")
                                            .font(.system(size: 10))
                                            .foregroundColor(theme.editorColors.text)
                                        if let description = skill.description {
                                            Text(description)
                                                .font(.system(size: 9))
                                                .foregroundColor(theme.editorColors.muted)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangleShape(cornerRadius: 5)
                                        .fill(viewModel.selectedSkillIDs.contains(skill.id) ? theme.editorColors.blue.opacity(0.10) : Color.clear)
                                )
                            }
                            .buttonStyle(DefaultButtonStyle())
                        }
                    }
                }
                .frame(height: 154)
            }
            .padding(6)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surfaceElevated))
            .overlay {
                RoundedRectangleShape(cornerRadius: 6)
                    .stroke(theme.editorColors.border.opacity(0.45), lineWidth: 1)
            }
        }
    }

    private var filteredSkills: [EditorAgentSkill] {
        let query = skillSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return viewModel.availableSkills
        }
        return viewModel.availableSkills.filter { skill in
            skill.id.localizedCaseInsensitiveContains(query)
                || skill.name.localizedCaseInsensitiveContains(query)
                || skill.description?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What should we build?")
                .font(.system(size: 17))
                .foregroundColor(theme.editorColors.text)
            Text(viewModel.statusMessage ?? "The agent can work with code, scenes, assets, project documentation, and the live AdaEngine runtime.")
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
                .lineLimit(4)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(promptSuggestions, id: \.self) { suggestion in
                    Button(action: { viewModel.prompt = suggestion }) {
                        Text(suggestion)
                            .font(.system(size: 10))
                            .foregroundColor(theme.editorColors.blue)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.blue.opacity(0.08)))
                    }
                    .buttonStyle(DefaultButtonStyle())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var promptSuggestions: [String] {
        if viewModel.sceneContext != nil {
            return [
                "Explain the selected entity and its components",
                "Improve this scene and verify it with a screenshot",
                "Find missing assets or invalid references"
            ]
        }
        if viewModel.codeSelection != nil {
            return [
                "Explain and improve the selected code",
                "Find related project code and tests",
                "Fix this code and validate the result"
            ]
        }
        return [
            "Build a playable scene for this project",
            "Find and fix current project errors",
            "Explain the project architecture"
        ]
    }

    @ViewBuilder
    private var autocompleteList: some View {
        if !viewModel.autocompleteSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(viewModel.autocompleteSuggestions, id: \.id) { entry in
                    Button(action: { viewModel.insertAutocomplete(entry) }) {
                        HStack(spacing: 6) {
                            Text(entry.isDirectory ? "-" : "<>")
                                .font(.system(size: 9))
                                .foregroundColor(theme.editorColors.blue)
                                .frame(width: 18)
                            Text(entry.path)
                                .font(.system(size: 10))
                                .foregroundColor(theme.editorColors.muted)
                                .lineLimit(1)
                            Spacer()
                        }
                        .frame(height: 22)
                    }
                    .buttonStyle(DefaultButtonStyle())
                }
            }
            .padding(6)
            .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.background))
        }
    }

    private func contextFileLabel(_ path: String) -> String {
        let fileExtension = URL(fileURLWithPath: path).pathExtension.uppercased()
        if ["PNG", "JPG", "JPEG", "GIF"].contains(fileExtension) {
            return "IMG"
        }
        return fileExtension.isEmpty ? "FILE" : String(fileExtension.prefix(4))
    }

}
