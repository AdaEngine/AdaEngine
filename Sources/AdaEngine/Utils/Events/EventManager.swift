//
//  EventManager.swift
//  
//
//  Created by v.prusakov on 7/3/22.
//

public protocol Event { }

public final class EventManager {
    
    public static let `default`: EventManager = EventManager()
    
    private var subscribers: [ObjectIdentifier : WeakSet<EventSubscriber>] = [:]
    
    public func subscribe<T: Event>(
        to: T.Type,
        on source: EventSource? = nil,
        completion: @escaping (T) -> Void
    ) -> AnyCancellable {
        let subscriber = EventSubscriber(source: source, completion: completion)
        
        let key = ObjectIdentifier(T.self)
        self.subscribers[key, default: []].insert(subscriber)
        
        return AnyCancellable(subscriber)
    }
    
    public func send<T: Event>(_ event: T) {
        let key = ObjectIdentifier(T.self)
        self.subscribers[key]?.forEach { subscriber in
            subscriber.completion?(event)
        }
    }
    
    public func send<T: Event>(_ event: T, source: EventSource) {
        let key = ObjectIdentifier(T.self)
        self.subscribers[key]?.forEach { subscriber in
            if let eventSource = subscriber.source, eventSource !== source {
                return
            }
            
            subscriber.completion?(event)
        }
    }
}

private class EventSubscriber: Cancellable {
    let source: EventSource?
    private(set) var completion: ((Any) -> Void)?
    
    init<T>(source: EventSource?, completion: @escaping (T) -> Void) {
        self.source = source
        self.completion = { value in
            completion(value as! T)
        }
    }
    
    func cancel() {
        self.completion = nil
    }
}

public protocol EventSource: AnyObject {
    func subscribe<E: Event>(to event: E.Type, on eventSource: EventSource?, completion: @escaping (E) -> Void) -> AnyCancellable
}

public extension EventSource {
    func subscribe<E: Event>(
        to event: E.Type,
        on source: EventSource? = nil,
        completion: @escaping (E) -> Void
    ) -> AnyCancellable {
        return self.subscribe(to: event, on: source, completion: completion)
    }
}
