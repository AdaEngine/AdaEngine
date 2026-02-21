//
//  TextField.swift
//  AdaEngine
//
//  Created by Codex on 19.02.2026.
//

/// A control that displays an editable text interface.
public struct TextField: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    let placeholder: String
    let text: Binding<String>

    /// Creates a text field with an optional placeholder.
    ///
    /// - Parameters:
    ///   - placeholder: Text displayed when the field is empty.
    ///   - text: Two-way binding for the field content.
    public init(_ placeholder: String = "", text: Binding<String>) {
        self.placeholder = placeholder
        self.text = text
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        TextFieldViewNode(inputs: context, content: self)
    }
}
