//
//  TextEditor.swift
//  AdaEngine
//
//  Created by Codex on 18.05.2026.
//

import AdaUtils

/// Colors used by a text editor primitive.
public struct TextEditorColors: Hashable, Sendable {
    var background: Color
    var border: Color
    var focusedBorder: Color
    var gutter: Color
    var gutterRule: Color
    var currentLineBackground: Color
    var selection: Color

    /// Creates a text editor color set.
    public init(
        background: Color,
        border: Color,
        focusedBorder: Color,
        gutter: Color,
        gutterRule: Color,
        currentLineBackground: Color,
        selection: Color
    ) {
        self.background = background
        self.border = border
        self.focusedBorder = focusedBorder
        self.gutter = gutter
        self.gutterRule = gutterRule
        self.currentLineBackground = currentLineBackground
        self.selection = selection
    }

    static let standard = TextEditorColors(
        background: Color.fromHex(0xFAFAFA),
        border: Color.fromHex(0x969696),
        focusedBorder: Color.fromHex(0x2D7EFF),
        gutter: Color.fromHex(0x6F737A),
        gutterRule: Color.fromHex(0xD7D7D7),
        currentLineBackground: Color.fromHex(0x2D7EFF).opacity(0.10),
        selection: Color.fromHex(0x2D7EFF).opacity(0.26)
    )
}

/// A multi-line text editing view.
public struct TextEditor: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    let placeholder: String
    let text: Binding<String>

    /// Creates a text editor.
    ///
    /// - Parameters:
    ///   - placeholder: Text displayed when the editor is empty.
    ///   - text: Two-way binding for the editor content.
    public init(_ placeholder: String = "", text: Binding<String>) {
        self.placeholder = placeholder
        self.text = text
    }

    /// Creates a text editor.
    ///
    /// - Parameter text: Two-way binding for the editor content.
    public init(text: Binding<String>) {
        self.placeholder = ""
        self.text = text
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        TextEditorViewNode(inputs: context, content: self)
    }
}

public extension View {
    /// Sets colors for text editors within this view.
    func textEditorColors(_ colors: TextEditorColors) -> some View {
        self.environment(\.textEditorColors, colors)
    }
}

public extension EnvironmentValues {
    @Entry var textEditorColors: TextEditorColors = .standard
}
