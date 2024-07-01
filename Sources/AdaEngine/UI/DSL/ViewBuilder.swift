//
//  ViewBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

@MainActor
@resultBuilder public enum ViewBuilder {

    @_alwaysEmitIntoClient
    public static func buildBlock() -> EmptyView {
        return EmptyView()
    }

    @_alwaysEmitIntoClient
    public static func buildBlock<Content>(_ content: Content) -> Content where Content : View {
        return content
    }

    @_alwaysEmitIntoClient
    public static func buildBlock<each Content>(_ content: repeat each Content) -> ViewTuple<(repeat each Content)> where repeat each Content : View {
        return ViewTuple(value: (repeat each content))
    }

    @_alwaysEmitIntoClient
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: View {
        content
    }
}

extension ViewBuilder {
    @_alwaysEmitIntoClient
    public static func buildIf<Content>(_ content: Content?) -> Content? where Content: View {
        content
    }

    @_alwaysEmitIntoClient
    public static func buildEither<TrueContent, FalseContent>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: View, FalseContent: View {
        _ConditionalContent(storage: .trueContent(first))
    }

    @_alwaysEmitIntoClient
    public static func buildEither<TrueContent, FalseContent>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: View, FalseContent: View {
        _ConditionalContent(storage: .falseContent(second))
    }
}

extension ViewBuilder {
    /// Processes view content for a conditional compiler-control
    /// statement that performs an availability check.
    public static func buildLimitedAvailability<Content>(_ content: Content) -> AnyView where Content : View {
        AnyView(content)
    }
}


public struct _ConditionalContent<TrueContent, FalseContent> {

    public enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }

    let storage: _ConditionalContent<TrueContent, FalseContent>.Storage

    public init(storage: Storage) {
        self.storage = storage
    }
}

extension _ConditionalContent: View where TrueContent: View, FalseContent: View {

    public typealias Body = Never

    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        switch view[\.storage].value {
        case .trueContent(let trueContent):
            return TrueContent._makeView(_ViewGraphNode(value: trueContent), inputs: inputs)
        case .falseContent(let falseContent):
            return FalseContent._makeView(_ViewGraphNode(value: falseContent), inputs: inputs)
        }
    }
}
