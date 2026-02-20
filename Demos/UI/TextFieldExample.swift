//
//  TextFieldExample.swift
//  AdaEngine
//
//  Created by Codex on 19.02.2026.
//

import AdaEngine

@main
struct TextFieldExample: App {
    var body: some AppScene {
        WindowGroup {
            TextFieldDemoView()
        }
        .windowMode(.windowed)
    }
}

struct TextFieldDemoView: View {

    @State private var title: String = "Ship TextField demo"
    @State private var assignee: String = "Ada Engine Team"
    @State private var notes: String = "Select this text and try copy/paste, undo and redo."

    var body: some View {
        ZStack {
            Color.fromHex(0xEDEFF3)

            VStack(alignment: .leading, spacing: 12) {
                Text("TextField Demo")
                    .fontSize(22)

                Text("Try keyboard shortcuts: Cmd/Ctrl+C, Cmd/Ctrl+V, Cmd/Ctrl+X, Cmd/Ctrl+Z and Ctrl+Y.")
                    .fontSize(12)
                    .foregroundColor(Color.fromHex(0x5E636E))

                Divider()

                field(
                    title: "Task title",
                    placeholder: "Enter title",
                    text: $title
                )

                field(
                    title: "Assignee",
                    placeholder: "Enter assignee",
                    text: $assignee
                )
                .accentColor(.green)

                field(
                    title: "Notes",
                    placeholder: "Short note",
                    text: $notes
                )
                .accentColor(.red)

                HStack(alignment: .center, spacing: 8) {
                    actionButton("Clear", background: Color.fromHex(0xE05252)) {
                        title = ""
                        assignee = ""
                        notes = ""
                    }

                    actionButton("Fill sample", background: Color.fromHex(0x2D7EFF)) {
                        title = "Build TextField node"
                        assignee = "Codex"
                        notes = "Supports selection, clipboard, undo and redo."
                    }

                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current values")
                        .fontSize(11)
                        .foregroundColor(Color.fromHex(0x5E636E))

                    Text("title: \(title)")
                        .fontSize(11)
                    Text("assignee: \(assignee)")
                        .fontSize(11)
                    Text("notes: \(notes)")
                        .fontSize(11)
                }
            }
            .padding(18)
            .frame(width: 560)
            .background(.white)
            .border(Color.fromHex(0xC4CAD3))
        }
    }

    @ViewBuilder
    private func field(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .fontSize(11)
                .foregroundColor(Color.fromHex(0x5E636E))

            TextField(placeholder, text: text)
                .frame(width: 520, height: 36)
        }
    }

    private func actionButton(_ title: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontSize(12)
                .foregroundColor(.white)
                .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .background(background)
                .border(background.opacity(0.75))
        }
    }
}
