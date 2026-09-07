import AdaDebugging
import AdaEngine
import Foundation

struct EditorDebugPanel: View {
    let debugger: EditorDebugger
    @Environment(\.theme) private var theme
    @State private var selectedTab = "Console"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            controls
            Text(debugger.status.isEmpty ? debugger.session.reason : debugger.status)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
                .lineLimit(2)
            HStack(spacing: 10) {
                ForEach(["Breakpoints", "Call Stack", "Variables", "Watches", "Console"], id: \.self) { tab in
                    Button(tab) { selectedTab = tab }
                        .foregroundColor(selectedTab == tab ? theme.editorColors.blue : theme.editorColors.text)
                        .accessibilityIdentifier("AdaEditor.Debug.Tab.\(tab)")
                }
            }
            .font(.system(size: 11))
            .buttonStyle(DefaultButtonStyle())
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(10)
        .accessibilityIdentifier("AdaEditor.Debug.Panel")
    }

    private var controls: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(EditorDebugLanguage.allCases, id: \.self) { language in
                    Button(language.rawValue) { debugger.selectedLanguage = language }
                        .foregroundColor(debugger.selectedLanguage == language ? theme.editorColors.blue : theme.editorColors.muted)
                }
                action("Pause", command: "pause", enabled: debugger.session.state == .running)
                action("Continue", command: "continue", enabled: debugger.session.state == .paused)
                action("Step Into", command: "stepIn", enabled: debugger.session.state == .paused)
                action("Step Over", command: "next", enabled: debugger.session.state == .paused)
                action("Step Out", command: "stepOut", enabled: debugger.session.state == .paused)
                Button("Stop") { debugger.stop() }.disabled(!debugger.isActive)
            }
            .font(.system(size: 11))
            .buttonStyle(DefaultButtonStyle())
        }
    }

    @ViewBuilder private var content: some View {
        switch selectedTab {
        case "Breakpoints":
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 6) {
                    if debugger.breakpoints.isEmpty { Text("Click the source gutter to add a breakpoint.") }
                    ForEach(debugger.breakpoints) { breakpoint in
                        let target = URL(fileURLWithPath: breakpoint.path).pathExtension == "swift" ? debugger.swift : debugger.adaScript
                        HStack(spacing: 8) {
                            Button(breakpoint.enabled ? "●" : "○") {
                                debugger.setBreakpointEnabled(breakpoint, enabled: !breakpoint.enabled)
                            }
                            Text("\(URL(fileURLWithPath: breakpoint.path).lastPathComponent):\(breakpoint.line)")
                            Text(target.verifiedBreakpoints[breakpoint.id] == true ? "Verified" : "Pending")
                                .foregroundColor(theme.editorColors.muted)
                            Button("Remove") { debugger.toggleBreakpoint(path: breakpoint.path, line: breakpoint.line) }
                        }
                        if let message = target.breakpointMessages[breakpoint.id] { Text(message) }
                    }
                }.font(.system(size: 11))
            }
        case "Call Stack":
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(debugger.session.threads.map(\.id), id: \.self) { identifier in
                        Button(debugger.session.threads.first { $0.id == identifier }?.name ?? "Thread") {
                            Task { await debugger.session.selectThread(identifier) }
                        }
                    }
                    ForEach(debugger.session.frames) { frame in
                        Button("\(frame.name) · \(frame.path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""):\(frame.line)") {
                            Task { await debugger.session.selectFrame(frame) }
                        }
                        .foregroundColor(debugger.session.selectedFrameID == frame.id ? theme.editorColors.blue : theme.editorColors.text)
                    }
                }.font(.system(size: 11))
            }
        case "Variables":
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(debugger.session.variables.enumerated()), id: \.offset) { item in
                        EditorDebugVariableRow(session: debugger.session, variable: item.element, depth: 0)
                            .id("\(debugger.session.stopGeneration):\(debugger.session.selectedFrameID ?? -1):\(item.offset)")
                    }
                }
            }
        case "Watches":
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    TextField("Expression", text: Binding(get: { debugger.watchExpression }, set: { debugger.watchExpression = $0 }), onSubmit: debugger.addWatch)
                        .accessibilityIdentifier("AdaEditor.Debug.WatchExpression")
                    Button("Add") { debugger.addWatch() }
                        .accessibilityIdentifier("AdaEditor.Debug.AddWatch")
                }
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(debugger.watches, id: \.self) { expression in
                            HStack(spacing: 8) {
                                Text("\(expression) = \(debugger.session.watchValues[expression] ?? "Pause to evaluate")")
                                Button("Remove") { debugger.removeWatch(expression) }
                            }
                        }
                    }.font(.system(size: 11))
                }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(debugger.session.console.enumerated()), id: \.offset) { line in
                            Text(line.element).font(AdaEditorCodeFont.font(size: 11))
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                HStack(spacing: 8) {
                    TextField(debugger.selectedLanguage == .swift ? "LLDB command" : "AdaScript command", text: Binding(
                        get: { debugger.command }, set: { debugger.command = $0 }
                    ), onSubmit: debugger.sendCommand)
                    .accessibilityIdentifier("AdaEditor.Debug.Command")
                    Button("Send") { debugger.sendCommand() }
                        .accessibilityIdentifier("AdaEditor.Debug.Send")
                }.font(.system(size: 12))
            }
        }
    }

    private func action(_ title: String, command: String, enabled: Bool) -> some View {
        Button(title) { Task { await debugger.session.control(command) } }
            .disabled(!enabled)
            .accessibilityIdentifier("AdaEditor.Debug.\(command)")
    }
}

private struct EditorDebugVariableRow: View {
    let session: DebugSession
    let variable: DebugVariable
    let depth: Int
    @State private var children: [DebugVariable] = []
    @State private var expanded = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if variable.reference > 0, depth < 8 {
                    Button(expanded ? "▾" : "▸") {
                        expanded.toggle()
                        if expanded {
                            Task {
                                do { children = try await session.children(reference: variable.reference) }
                                catch { self.error = error.localizedDescription }
                            }
                        }
                    }
                }
                Text("\(variable.name): \(variable.type ?? "") = \(variable.value)")
                if let address = variable.memoryReference { Text(address) }
            }
            if expanded {
                if let error { Text(error) }
                ForEach(Array(children.enumerated()), id: \.offset) { child in
                    AnyView(EditorDebugVariableRow(session: session, variable: child.element, depth: depth + 1))
                        .padding(.leading, 14)
                }
            }
        }.font(AdaEditorCodeFont.font(size: 11))
    }
}
