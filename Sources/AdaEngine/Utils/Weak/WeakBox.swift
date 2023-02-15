//
//  WeakBox.swift
//  
//
//  Created by v.prusakov on 7/3/22.
//

public class WeakBox<T: AnyObject>: Identifiable, Hashable {
    
    public private(set) weak var value: T?
    
    public var isEmpty: Bool {
        return value == nil
    }
    
    public let id: ObjectIdentifier
    
    public init(value: T) {
        self.value = value
        self.id = ObjectIdentifier(value)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    public static func == (lhs: WeakBox<T>, rhs: WeakBox<T>) -> Bool {
        return lhs.id == rhs.id
    }
}
