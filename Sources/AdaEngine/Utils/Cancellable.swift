//
//  Cancellable.swift
//  
//
//  Created by v.prusakov on 7/3/22.
//

public protocol Cancellable {
    func cancel()
}

public extension AnyCancellable {
    func store(in buffer: inout Set<AnyCancellable>) {
        buffer.insert(self)
    }
}

public struct AnyCancellable: Cancellable, Hashable, Equatable {
    
    let id: UUID
    
    let cancellable: Cancellable
    
    init<T: Cancellable>(_ cancellable: T) {
        self.id = UUID()
        self.cancellable = cancellable
    }
    
    public func cancel() {
        self.cancellable.cancel()
    }
    
    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
}
