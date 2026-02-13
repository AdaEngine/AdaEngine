//
//  EventManagerModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

import AdaUtils

public extension View {
    /// Subscribe to EventManager events.
    func onEvent<E: Event>(
        _ event: E.Type,
        perform action: @escaping @Sendable (E) -> Void
    ) -> some View {
        self.modifier(
            EventManagerModifier(
                content: self,
                completion: action
            )
        )
    }
}

struct EventManagerModifier<Content: View, E: Event>: ViewModifier, ViewNodeBuilder {

    let content: Content
    let completion: @Sendable (E) -> Void

    func buildViewNode(in context: BuildContext) -> ViewNode {
        EventManagerNode(
            content: content,
            contentNode: context.makeNode(from: content),
            manager: context.environment.eventManager,
            completion: completion
        )
    }
}

private final class EventManagerNode<E: Event>: ViewModifierNode {

    let cancellable: any Cancellable

    init<Content: View>(
        content: Content,
        contentNode: ViewNode,
        manager: EventManager,
        completion: @escaping @Sendable (E) -> Void
    ) {
        self.cancellable = manager.subscribe(to: E.self, completion: completion)
        super.init(contentNode: contentNode, content: content)
    }

    deinit {
        cancellable.cancel()
    }
}

struct EventManagerEnvironmentKey: EnvironmentKey {
    static let defaultValue = EventManager.default
}

public extension EnvironmentValues {
    var eventManager: EventManager {
        get { self[EventManagerEnvironmentKey.self] }
        set { self[EventManagerEnvironmentKey.self] = newValue }
    }
}
