//
//  ComponentsBuilder.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/9/24.
//

// Contains collection of components.
private struct ComponentBuilderTuple: Component {
    let components: [any Component]
}

/// A custom parameter attribute that bundle components from closures.
///
/// We typically use ``ComponentsBuilder`` as a parameter attribute for components bundle.
///
/// - Note: More profitable for performance use solutions like ``Entity/ComponentSet/+=(lhs:rhs:)`` or ``Entity/ComponentSet/set(_:)-2oz15`` in ``Entity/ComponentSet`` object.
@resultBuilder public enum ComponentsBuilder {

    public static func buildBlock(_ components: Component...) -> Component {
        ComponentBuilderTuple(components: components)
    }

    public static func buildOptional(_ component: Component?) -> Component {
        ComponentBuilderTuple(components: component == nil ? [] : [component!])
    }

    public static func buildArray(_ components: [Component]) -> Component {
        ComponentBuilderTuple(components: components)
    }

    @_alwaysEmitIntoClient
    public static func buildLimitedAvailability(_ component: Component) -> Component {
        component
    }

    public static func buildEither(first component: Component) -> Component {
        component
    }

    public static func buildEither(second component: Component) -> Component {
        component
    }

    // unwrap all components
    public static func buildFinalResult(_ component: Component) -> [Component] {
        return self.unpackComponentBuilderTuple(component)
    }

    private static func unpackComponentBuilderTuple(_ component: Component) -> [Component] {
        guard let tuple = component as? ComponentBuilderTuple else {
            return [component]
        }

        var components: [Component] = []

        for item in tuple.components {
            if item is ComponentBuilderTuple {
                components.append(contentsOf: unpackComponentBuilderTuple(item))
            } else {
                components.append(item)
            }
        }

        return components
    }
}
