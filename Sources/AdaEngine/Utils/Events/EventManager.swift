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
    
    public func subscribe<T: Event>(for: T.Type, completion: @escaping (T) -> Void) -> Cancellable {
        let subscriber = EventSubscriber(completion: completion)
        
        let key = ObjectIdentifier(T.self)
        self.subscribers[key, default: []].insert(subscriber)
        
        return subscriber
    }
    
    public func send<T: Event>(_ event: T) {
        let key = ObjectIdentifier(T.self)
        self.subscribers[key]?.forEach { subscriber in
            subscriber.completion?(event)
        }
    }
}

private class EventSubscriber: Cancellable {
    private(set) var completion: ((Any) -> Void)?
    
    init<T>(completion: @escaping (T) -> Void) {
        self.completion = { value in
            completion(value as! T)
        }
    }
    
    func cancel() {
        self.completion = nil
    }
}
