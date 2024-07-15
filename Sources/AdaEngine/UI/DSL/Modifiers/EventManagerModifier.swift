//
//  EventManagerModifier.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 02.07.2024.
//

extension View {
    func onEvent<E: Event>(_ event: E.Type, completion: @escaping (E) -> Void) -> some View {
        self.modifier(
            EventManagerModifier(
                content: self,
                completion: completion
            )
        )
    }
}

struct EventManagerModifier<Content: View, E: Event>: ViewModifier, ViewNodeBuilder {

    let content: Content
    let completion: (E) -> Void

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        EventManagerNode(
            content: content,
            contentNode: inputs.makeNode(from: content),
            manager: inputs.environment.eventManager,
            completion: completion
        )
    }
}

private final class EventManagerNode<E: Event>: ViewModifierNode {

    let cancellable: any Cancellable

    init<Content: View>(content: Content, contentNode: ViewNode, manager: EventManager, completion: @escaping (E) -> Void) {
        self.cancellable = manager.subscribe(to: E.self, completion: completion)
        super.init(contentNode: contentNode, content: content)
    }
}

struct EventManagerEnvironmentKey: EnvironmentKey {
    static var defaultValue = EventManager.default
}

public extension EnvironmentValues {
    var eventManager: EventManager {
        get { self[EventManagerEnvironmentKey.self] }
        set { self[EventManagerEnvironmentKey.self] = newValue }
    }
}
