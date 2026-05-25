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

/// A colored token span rendered by ``TextEditor``.
public struct TextEditorTokenSpan: Hashable, Sendable {
    public var line: Int
    public var startColumn: Int
    public var length: Int
    public var color: Color

    public init(line: Int, startColumn: Int, length: Int, color: Color) {
        self.line = line
        self.startColumn = startColumn
        self.length = length
        self.color = color
    }
}

/// A zero-based source position inside ``TextEditor`` content.
public struct TextEditorSourcePosition: Hashable, Sendable {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

/// A zero-based source range inside ``TextEditor`` content.
public struct TextEditorSourceRange: Hashable, Sendable {
    public var start: TextEditorSourcePosition
    public var end: TextEditorSourcePosition

    public init(start: TextEditorSourcePosition, end: TextEditorSourcePosition) {
        self.start = start
        self.end = end
    }
}

/// A context menu item emitted by ``TextEditor`` source interactions.
public struct TextEditorContextMenuItem {
    public var title: String
    public var action: (() -> Void)?
    public var submenu: [TextEditorContextMenuItem]

    public init(title: String, action: (() -> Void)? = nil, submenu: [TextEditorContextMenuItem] = []) {
        self.title = title
        self.action = action
        self.submenu = submenu
    }
}

/// Optional source-aware interactions for ``TextEditor``.
public struct TextEditorSourceInteraction {
    public var highlightedRanges: [TextEditorSourceRange]
    public var focusedRange: TextEditorSourceRange?
    public var onHover: ((TextEditorSourcePosition?) -> Void)?
    public var onPrimaryClick: ((TextEditorSourcePosition) -> Void)?
    public var contextMenuItems: ((TextEditorSourcePosition) -> [TextEditorContextMenuItem])?

    public init(
        highlightedRanges: [TextEditorSourceRange] = [],
        focusedRange: TextEditorSourceRange? = nil,
        onHover: ((TextEditorSourcePosition?) -> Void)? = nil,
        onPrimaryClick: ((TextEditorSourcePosition) -> Void)? = nil,
        contextMenuItems: ((TextEditorSourcePosition) -> [TextEditorContextMenuItem])? = nil
    ) {
        self.highlightedRanges = highlightedRanges
        self.focusedRange = focusedRange
        self.onHover = onHover
        self.onPrimaryClick = onPrimaryClick
        self.contextMenuItems = contextMenuItems
    }
}

/// A multi-line text editing view.
public struct TextEditor: View {
    let placeholder: String
    let text: Binding<String>
    let tokenSpans: [TextEditorTokenSpan]
    let sourceInteraction: TextEditorSourceInteraction?

    public var body: some View {
        ScrollView([.horizontal, .vertical]) {
            TextEditorPrimitive(
                placeholder: placeholder,
                text: text,
                tokenSpans: tokenSpans,
                sourceInteraction: sourceInteraction
            )
        }
    }

    /// Creates a text editor.
    ///
    /// - Parameters:
    ///   - placeholder: Text displayed when the editor is empty.
    ///   - text: Two-way binding for the editor content.
    public init(
        _ placeholder: String = "",
        text: Binding<String>,
        tokenSpans: [TextEditorTokenSpan] = [],
        sourceInteraction: TextEditorSourceInteraction? = nil
    ) {
        self.placeholder = placeholder
        self.text = text
        self.tokenSpans = tokenSpans
        self.sourceInteraction = sourceInteraction
    }

    /// Creates a text editor.
    ///
    /// - Parameter text: Two-way binding for the editor content.
    public init(
        text: Binding<String>,
        tokenSpans: [TextEditorTokenSpan] = [],
        sourceInteraction: TextEditorSourceInteraction? = nil
    ) {
        self.placeholder = ""
        self.text = text
        self.tokenSpans = tokenSpans
        self.sourceInteraction = sourceInteraction
    }

}

struct TextEditorPrimitive: View, ViewNodeBuilder {
    typealias Body = Never
    var body: Never { fatalError() }

    let placeholder: String
    let text: Binding<String>
    let tokenSpans: [TextEditorTokenSpan]
    let sourceInteraction: TextEditorSourceInteraction?

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
