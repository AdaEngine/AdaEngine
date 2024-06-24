//
//  Text.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public struct Text: Widget, WidgetNodeBuilder {

    public typealias Body = Never

    final class Storage {
        fileprivate(set) var text: AttributedText
        var foregroundColor: Color?

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

        func applyingEnvironment(_ environment: WidgetEnvironmentValues) -> AttributedText {
            if let font = environment.font {
                self.text.font = font
            }
            
            if self.foregroundColor == nil {
                self.text.foregroundColor = environment.foregroundColor
            }
            
            return self.text
        }
    }

    let storage: Storage

    public init(_ text: String) {
        self.storage = Storage(string: text)
    }

    public init(attributedText: AttributedText) {
        self.storage = Storage(attributedText: attributedText)
    }

    init(_ storage: Storage) {
        self.storage = storage
    }

    func makeWidgetNode(context: Context) -> WidgetNode {
        return TextWidgetNode(context: context, content: self)
    }
}

public extension Text {
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

    static func + (lhs: Text, rhs: Text) -> Text {
        let newStorage = lhs.storage.concatinating(other: rhs.storage)
        return Text(newStorage)
    }
}

public extension Widget {
    func font(_ font: Font?) -> some Widget {
        return self.environment(\.font, font)
    }

    func foregroundColor(_ color: Color) -> some Widget {
        return self.environment(\.foregroundColor, color)
    }
}
