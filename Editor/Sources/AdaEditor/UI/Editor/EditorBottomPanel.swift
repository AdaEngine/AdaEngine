//
//  EditorBottomPanel.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 17.05.2026.
//

import AdaEngine
import Foundation

struct EditorBottomPanel: View {
    @State var viewModel: EditorViewModel
    @Environment(\.metrics) private var metrics
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach(metrics.outputTabs, id: \.self) { tab in
                    outputTab(tab)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(theme.editorColors.surface)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    panelContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background {
            RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner)
                .fill(theme.editorColors.surfaceElevated)
        }
        .mask(RoundedRectangleShape(cornerRadius: metrics.panelsRoundedCorner))
    }

    @ViewBuilder
    private var panelContent: some View {
        switch viewModel.activeOutputTab {
        case "Problems":
            if viewModel.problems.isEmpty {
                outputLine("No problems. \(viewModel.workspaceStatus.title)")
            } else {
                ForEach(viewModel.problems, id: \.self) { problem in
                    outputLine(
                        "\(problem.severity.rawValue.uppercased()) \(problem.filePath):\(problem.range.start.line + 1):\(problem.range.start.character + 1) \(problem.message)",
                        color: diagnosticColor(for: problem.severity)
                    )
                }
            }
        case "Build":
            commandButton("Build All") { viewModel.buildAll() }
            ForEach(viewModel.packageModel?.targets.map(\.name).sorted() ?? [], id: \.self) { target in
                commandButton("Build \(target)") { viewModel.buildTarget(target) }
            }
            outputSectionTitle("Build Output")
            ForEach(viewModel.outputLines) { line in
                outputLine(line.text, color: logColor(for: line.text))
            }
        case "Tests":
            commandButton("Run All Tests") { viewModel.runTests() }
            ForEach(viewModel.testTargets, id: \.self) { target in
                commandButton("Run \(target)") { viewModel.runTests(filter: target) }
            }
        case "References":
            if viewModel.symbolReferences.isEmpty {
                outputLine("No references.")
            } else {
                ForEach(viewModel.symbolReferences, id: \.self) { reference in
                    outputLine("\(reference.filePath):\(reference.range.start.line + 1):\(reference.range.start.character + 1)")
                }
            }
        default:
            ForEach(viewModel.outputLines) { line in
                outputLine(line.text, color: logColor(for: line.text))
            }
        }
    }

    private func outputLine(_ line: String, color: Color? = nil) -> some View {
        Text(line)
            .font(.system(size: 11))
            .foregroundColor(color ?? logColor(for: line))
            .lineBreakMode(.byCharWrapping)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func outputSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10))
            .foregroundColor(theme.editorColors.text)
            .padding(.top, 6)
    }

    private func diagnosticColor(for severity: EditorDiagnosticSeverity) -> Color {
        switch severity {
        case .error:
            return Color(red: 245 / 255, green: 110 / 255, blue: 110 / 255)
        case .warning:
            return Color(red: 234 / 255, green: 192 / 255, blue: 102 / 255)
        case .information:
            return Color(red: 114 / 255, green: 180 / 255, blue: 255 / 255)
        case .hint:
            return theme.editorColors.purple.opacity(0.92)
        }
    }

    private func logColor(for line: String) -> Color {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedLine = trimmedLine.lowercased()

        if trimmedLine.hasPrefix("$ ") {
            return theme.editorColors.blue.opacity(0.88)
        }
        if lowercasedLine.hasPrefix("exited with code 0") || lowercasedLine.contains("succeeded") || lowercasedLine.contains("completed") {
            return Color(red: 110 / 255, green: 205 / 255, blue: 126 / 255)
        }
        if lowercasedLine.contains("error:") || lowercasedLine.hasPrefix("error") || lowercasedLine.contains(" failed") || lowercasedLine.hasPrefix("failed") {
            return Color(red: 245 / 255, green: 110 / 255, blue: 110 / 255)
        }
        if lowercasedLine.contains("warning:") || lowercasedLine.hasPrefix("warning") {
            return Color(red: 234 / 255, green: 192 / 255, blue: 102 / 255)
        }
        if lowercasedLine.hasPrefix("information") || lowercasedLine.hasPrefix("info") || lowercasedLine.hasPrefix("note:") || lowercasedLine.contains(" note:") {
            return Color(red: 114 / 255, green: 180 / 255, blue: 255 / 255)
        }
        if lowercasedLine.hasPrefix("debug") || lowercasedLine.hasPrefix("trace") {
            return theme.editorColors.purple.opacity(0.86)
        }
        if lowercasedLine.hasPrefix("exited with code") {
            return Color(red: 245 / 255, green: 110 / 255, blue: 110 / 255)
        }

        return theme.editorColors.muted
    }

    private func commandButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(theme.editorColors.blue)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(RoundedRectangleShape(cornerRadius: 5).fill(theme.editorColors.blue.opacity(0.12)))
        }
        .buttonStyle(DefaultButtonStyle())
    }

    private func outputTab(_ tab: String) -> some View {
        let active = tab == viewModel.activeOutputTab

        return Button(action: { viewModel.selectOutputTab(tab) }) {
            Text(tab)
                .font(.system(size: 11))
                .foregroundColor(active ? theme.editorColors.text : theme.editorColors.muted)
                .padding(.horizontal, metrics.outputTabHorizontalPadding)
                .frame(height: 24)
                .background(RoundedRectangleShape(cornerRadius: 5).fill(active ? theme.editorColors.surfaceElevated : theme.editorColors.surface.opacity(0.55)))
                .overlay {
                    RoundedRectangleShape(cornerRadius: 5)
                        .stroke(active ? theme.editorColors.blue.opacity(0.68) : theme.editorColors.border.opacity(0.36), lineWidth: 1)
                }
                .overlay(anchor: .bottom) {
                    if active {
                        RectangleShape()
                            .fill(theme.editorColors.blue)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(DefaultButtonStyle())
    }
}
