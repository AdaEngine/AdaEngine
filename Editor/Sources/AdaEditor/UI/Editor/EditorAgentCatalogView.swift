@_spi(AdaEngine) import AdaEngine

struct EditorAgentCatalogView: View {
    let agent: EditorAgentViewModel
    var loadsCatalog = true
    @Environment(\.theme) private var theme

    private var catalog: EditorAgentCatalogViewModel { agent.catalog }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACP Registry").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Refresh") { Task { await catalog.refresh() } }
                    .buttonStyle(actionButtonStyle)
                    .disabled(catalog.isBusy || agent.isConnectingCatalogAgent)
                    .accessibilityIdentifier("AdaEditor.Agents.Refresh")
            }
            #if os(macOS)
            Text("Connect an agent to this project, then open Agent Chat. Sign in through the agent's own account setup.")
                .font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
            SearchBar(
                text: Binding(get: { catalog.query }, set: { catalog.query = $0 }),
                prompt: "Search agents…",
                height: 34
            )
                .foregroundColor(theme.editorColors.text)
                .searchBarStyle(EditorAgentCatalogSearchBarStyle(theme: theme))
                .accessibilityIdentifier("AdaEditor.Agents.Search")
            HStack(spacing: 12) {
                ForEach(EditorAgentCatalogViewModel.Filter.allCases, id: \.rawValue) { filter in
                    Button(filter.rawValue) { catalog.filter = filter }
                        .buttonStyle(
                            EditorAgentCatalogFilterButtonStyle(
                                isActive: catalog.filter == filter,
                                theme: theme
                            )
                        )
                }
            }
            Text(catalog.status).font(.system(size: 11)).foregroundColor(theme.editorColors.muted).lineLimit(4)
            if !agent.settingsStatusMessage.isEmpty {
                Text(agent.settingsStatusMessage)
                    .font(.system(size: 11)).foregroundColor(theme.editorColors.text).lineLimit(6)
                    .accessibilityIdentifier("AdaEditor.Agents.ConnectionStatus")
            }
            if catalog.filter != .available {
                installedAgents
            }
            if catalog.filter != .installed {
                localAgents
                ForEach(catalog.visibleAgents.filter { item in
                    !catalog.installed.contains { $0.id == item.id } && !catalog.discovered.contains { $0.id == item.id }
                }) { item in
                    registryRow(item)
                }
            }
            #else
            Text("Local ACP agents can be installed and launched on macOS.").font(.system(size: 12))
            #endif
        }
        .accessibilityIdentifier("AdaEditor.Agents.Catalog")
        .onAppear {
            #if os(macOS)
            if loadsCatalog { Task { await catalog.loadIfNeeded() } }
            #endif
        }
    }

    private var installedAgents: some View {
        ForEach(catalog.installed.filter { catalog.query.isEmpty || $0.name.localizedCaseInsensitiveContains(catalog.query) }) { entry in
            HStack {
                Text("\(entry.name) · \(entry.version)").font(.system(size: 12))
                Spacer()
                if agent.isCatalogAgentSelected(entry) {
                    Text("Selected for this project")
                        .font(.system(size: 10)).foregroundColor(theme.editorColors.blue)
                        .accessibilityIdentifier("AdaEditor.Agents.Selected.\(entry.id)")
                }
                Button("Connect") { Task { await agent.connectCatalogAgent(installed: entry) } }
                    .buttonStyle(actionButtonStyle)
                    .disabled(!agent.canConnectCatalogAgent)
                    .accessibilityIdentifier("AdaEditor.Agents.Use.\(entry.id)")
                Button("Remove") { Task { await catalog.remove(entry) } }
                    .buttonStyle(actionButtonStyle)
                    .disabled(catalog.isBusy || agent.isConnectingCatalogAgent)
            }
        }
    }

    private var localAgents: some View {
        ForEach(catalog.discovered.filter { local in
            let searchableText = "\(local.name) \(local.id) \(local.path) \(catalog.adapter(for: local)?.description ?? "")"
            return !catalog.installed.contains { $0.id == local.id } &&
                (catalog.query.isEmpty || searchableText.localizedCaseInsensitiveContains(catalog.query))
        }) { local in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Found \(local.name)").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if local.target != nil {
                        Button("Add & Connect") { Task { await agent.connectCatalogAgent(local: local) } }
                            .buttonStyle(actionButtonStyle)
                            .disabled(!agent.canConnectCatalogAgent)
                            .accessibilityIdentifier("AdaEditor.Agents.AddLocal.\(local.id)")
                    } else if catalog.adapter(for: local) != nil {
                        Button("Install & Connect") { Task { await agent.connectCatalogAgent(local: local) } }
                            .buttonStyle(actionButtonStyle)
                            .disabled(!agent.canConnectCatalogAgent)
                            .accessibilityIdentifier("AdaEditor.Agents.InstallAdapter.\(local.id)")
                    }
                }
                Text(local.path).font(.system(size: 10)).foregroundColor(theme.editorColors.muted).lineLimit(2)
                if local.target == nil {
                    Text(catalog.adapter(for: local) != nil
                        ? "An ACP adapter is required. Install & Connect sets it up for this project."
                        : "ACP adapter unavailable. Refresh the registry or configure an ACP command below.")
                        .font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
                }
            }
        }
    }

    private func registryRow(_ item: EditorRegistryAgent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name).font(.system(size: 13, weight: .semibold))
                Text(item.version).font(.system(size: 10)).foregroundColor(theme.editorColors.muted)
                Spacer()
                Button("Install & Connect") { Task { await agent.connectCatalogAgent(registry: item) } }
                    .buttonStyle(actionButtonStyle)
                    .disabled(!agent.canConnectCatalogAgent)
                    .accessibilityIdentifier("AdaEditor.Agents.Install.\(item.id)")
            }
            Text(item.description).font(.system(size: 11)).foregroundColor(theme.editorColors.muted).lineLimit(3)
            Text(item.id).font(.system(size: 10)).foregroundColor(theme.editorColors.muted)
        }
        .padding(12)
        .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surfaceElevated))
    }

    private var actionButtonStyle: EditorAgentCatalogActionButtonStyle {
        EditorAgentCatalogActionButtonStyle(theme: theme)
    }
}

private struct EditorAgentCatalogSearchBarStyle: SearchBarStyle {
    let theme: Theme

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\u{E8B6}")
                .font(AdaEditorMaterialSymbolFont.font(size: 15))
                .foregroundColor(theme.editorColors.muted)
                .frame(width: 16, height: 16)
            configuration.label
            if !configuration.isEmpty {
                Button("×", action: configuration.clear)
                    .font(.system(size: 12))
                    .foregroundColor(theme.editorColors.muted)
                    .buttonStyle(DefaultButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surface))
        .overlay {
            RoundedRectangleShape(cornerRadius: 6)
                .stroke(theme.editorColors.border, lineWidth: 1)
        }
    }
}

private struct EditorAgentCatalogActionButtonStyle: ButtonStyle {
    let theme: Theme

    func makeBody(configuration: Configuration) -> some View {
        let isHighlighted = configuration.state.isHighlighted || configuration.state.isSelected
        let shape = RoundedRectangleShape(cornerRadius: 6)

        return configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(theme.editorColors.text)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minWidth: 68, minHeight: 28)
            .glassEffect(glass(isHighlighted: isHighlighted), in: shape)
            .overlay {
                shape.stroke(theme.editorColors.border, lineWidth: 1)
            }
            .opacity(configuration.state.isEnabled ? 1 : 0.48)
    }

    private func glass(isHighlighted: Bool) -> Glass {
        var glass = Glass.regular
        glass.blurRadius = 14
        glass.glassTintStrength = isHighlighted ? 0.72 : 0.46
        glass.edgeShadowStrength = 0
        glass.tintColor = isHighlighted
            ? theme.editorColors.surfaceElevated.opacity(0.62)
            : theme.editorColors.surface.opacity(0.48)
        return glass
    }
}

private struct EditorAgentCatalogFilterButtonStyle: ButtonStyle {
    let isActive: Bool
    let theme: Theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .foregroundColor(isActive ? theme.editorColors.blue : theme.editorColors.muted)
            .lineLimit(1)
            .frame(width: 72, height: 24)
            .opacity(configuration.state.isHighlighted ? 0.72 : 1)
    }
}
