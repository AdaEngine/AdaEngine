//
//  Text.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaText
import AdaUtils
import Math

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
    public var body: Never { fatalError() }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        TextViewNode(inputs: context, content: self)
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
    
    /// Sets the default font size for text in this view.
    func fontSize(_ pointSize: Double) -> some View {
        return self.transformEnvironment(\.font) { font in
            var newFont = font ?? Font.system(size: 17)
            newFont.pointSize = pointSize
            font = newFont
        }
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

extension Text {
    public struct Layout: Collection, Equatable, Sequence {
        public typealias Index = Int
        public typealias Element = TextLine

        private let lines: [TextLine]

        init(lines: [TextLine]) {
            self.lines = lines
        }

        public subscript(position: Int) -> TextLine {
            _read {
                yield self.lines[position]
            }
        }

        public var startIndex: Int {
            self.lines.startIndex
        }
        public var endIndex: Int {
            self.lines.endIndex
        }

        public func index(before i: Int) -> Int {
            self.lines.index(before: i)
        }

        public func index(after i: Int) -> Int {
            return self.lines.index(after: i)
        }
    }
}

extension Text {

    public struct Proxy {
        let layoutManager: TextLayoutManager

        public func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
            if proposal == .zero || proposal == .infinity {
                let size = self.layoutManager.boundingSize()
                return size
            }

            var idealWidth: Float = .infinity
            var idealHeight: Float = .infinity

            if let width = proposal.width, width != .infinity {
                idealWidth = width
            }

            if let height = proposal.height, height != .infinity {
                idealHeight = height
            }

            let size = self.layoutManager.boundingSize()
            return Size(
                width: min(idealWidth, size.width),
                height: min(idealHeight, size.height)
            )
        }
    }
}

/// A value that can replace the default text view rendering behavior.
public protocol TextRenderer: Animatable, Sendable {

    /// Draws layout into context.
    @MainActor func draw(layout: Text.Layout, in context: inout UIGraphicsContext)

    /// Returns the size of the text in proposal. The provided text proxy value may be used to query the sizing behavior of the underlying text layout.
    @MainActor func sizeThatFits(proposal: ProposedViewSize, text: Text.Proxy) -> Size
}

public extension TextRenderer {

  var animatableData: EmptyAnimatableData {
      get { EmptyAnimatableData() }
      // swiftlint:disable:next unused_setter_value
      set { }
  }

    func sizeThatFits(proposal: ProposedViewSize, text: Text.Proxy) -> Size {
        text.sizeThatFits(proposal)
    }
}

public extension View {
    /// Returns a new view such that any text views within it will use renderer to draw themselves.
    /// - Parameter renderer: The renderer value.
    /// - Returns: A new view that will use renderer to draw its text views.
    func textRendered<T: TextRenderer>(_ renderer: T) -> some View {
        self.environment(\.textRenderer, renderer)
    }
}

extension EnvironmentValues {
    /// Contains instance that can render text. If nil, will use default implementation ``DefaultRichTextRenderer``
    var textRenderer: (any TextRenderer)? {
        get {
            self[TextRendererKey.self]
        }
        set {
            self[TextRendererKey.self] = newValue
        }
    }

    private struct TextRendererKey: EnvironmentKey {
        static let defaultValue: (any TextRenderer)? = nil
    }
}
