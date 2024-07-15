//
//  Text.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct Text {

    let storage: Storage

    public init(_ text: String) {
        self.storage = Storage(string: text)
    }

    public init(_ attributedText: AttributedText) {
        self.storage = Storage(attributedText: attributedText)
    }

    init(_ storage: Storage) {
        self.storage = storage
    }

}

extension Text: View, ViewNodeBuilder {
    
    public typealias Body = Never
    
    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        TextViewNode(inputs: inputs, content: self)
    }
}

public extension Text {
    /// Sets the default font for text in this view.
    func font(_ font: Font?) -> Text {
        if let font = font {
            self.storage.text.font = font
        }
        return self
    }

    func foregroundColor(_ color: Color) -> Text {
        self.storage.foregroundColor = color
        return self
    }

    func lineLimit(_ number: Int?) -> Text {
        self.storage.lineLimit = number
        return self
    }

    static func + (lhs: Text, rhs: Text) -> Text {
        let newStorage = lhs.storage.concatinating(other: rhs.storage)
        return Text(newStorage)
    }
}

public extension View {
    /// Sets the default font for text in this view.
    func font(_ font: Font?) -> some View {
        return self.environment(\.font, font)
    }

    func foregroundColor(_ color: Color) -> some View {
        return self.environment(\.foregroundColor, color)
    }

    func lineLimit(_ number: Int?) -> some View {
        return self.environment(\.lineLimit, number)
    }
}

extension Text {
    final class Storage {
        fileprivate(set) var text: AttributedText
        var foregroundColor: Color?
        var lineLimit: Int?

        init(string: String) {
            self.text = AttributedText(string)
        }

        init(attributedText: AttributedText) {
            self.text = attributedText
        }

        func concatinating(other: Storage) -> Storage {
            var newText = self.text
            newText.append(other.text)
            return Storage(attributedText: newText)
        }

        func applyingEnvironment(_ environment: EnvironmentValues) -> AttributedText {
            if let font = environment.font {
                self.text.font = font
            }

            if lineLimit == nil {
                self.lineLimit = environment.lineLimit
            }

            if self.foregroundColor == nil {
                self.text.foregroundColor = environment.foregroundColor ?? .black
            }

            return self.text
        }
    }
}
