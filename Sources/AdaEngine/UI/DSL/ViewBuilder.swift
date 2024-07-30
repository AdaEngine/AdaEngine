//
//  ViewBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

/// A custom parameter attribute that constructs views from closures.
///
/// You typically use ``ViewBuilder`` as a parameter attribute for child view-producing closure parameters, allowing those closures to provide multiple child views.
@resultBuilder public enum ViewBuilder {

    /// Builds an empty view from a block containing no statements.
    @_alwaysEmitIntoClient
    public static func buildBlock() -> EmptyView {
        return EmptyView()
    }

    /// Passes a single view written as a child view through unmodified.
    @_alwaysEmitIntoClient
    public static func buildBlock<Content>(_ content: Content) -> Content where Content : View {
        return content
    }

    /// Passes a single view written as a child view through unmodified.
    @_alwaysEmitIntoClient
    public static func buildBlock<each Content>(_ content: repeat each Content) -> ViewTuple<(repeat each Content)> where repeat each Content : View {
        return ViewTuple(value: (repeat each content))
    }

    /// Builds an expression within the builder.
    @_alwaysEmitIntoClient
    public static func buildExpression<Content>(_ content: Content) -> Content where Content: View {
        content
    }
}

extension ViewBuilder {
    /// Produces an optional view for conditional statements in multi-statement closures that’s only visible when the condition evaluates to true.
    @_alwaysEmitIntoClient
    public static func buildIf<Content>(_ content: Content?) -> Content? where Content: View {
        content
    }

    /// Produces content for a conditional statement in a multi-statement closure when the condition is true.
    @_alwaysEmitIntoClient
    public static func buildEither<TrueContent, FalseContent>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: View, FalseContent: View {
        _ConditionalContent(storage: .trueContent(first))
    }

    /// Produces content for a conditional statement in a multi-statement closure when the condition is false.
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
    public var body: Never { fatalError() }

    @MainActor @preconcurrency
    public static func _makeView(_ view: _ViewGraphNode<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        switch view[\.storage].value {
        case .trueContent(let trueContent):
            return TrueContent._makeView(_ViewGraphNode(value: trueContent), inputs: inputs)
        case .falseContent(let falseContent):
            return FalseContent._makeView(_ViewGraphNode(value: falseContent), inputs: inputs)
        }
    }

    @MainActor @preconcurrency
    public static func _makeListView(_ view: _ViewGraphNode<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        switch view[\.storage].value {
        case .trueContent(let trueContent):
            return TrueContent._makeListView(_ViewGraphNode(value: trueContent), inputs: inputs)
        case .falseContent(let falseContent):
            return FalseContent._makeListView(_ViewGraphNode(value: falseContent), inputs: inputs)
        }
    }
}
