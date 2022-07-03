//
//  WeakBox.swift
//  
//
//  Created by v.prusakov on 7/3/22.
//

class WeakBox<T: AnyObject>: Identifiable, Hashable {
    
    weak var value: T?
    
    var isEmpty: Bool {
        return value == nil
    }
    
    let id: ObjectIdentifier
    
    init(value: T) {
        self.value = value
        self.id = ObjectIdentifier(value)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    static func == (lhs: WeakBox<T>, rhs: WeakBox<T>) -> Bool {
        return lhs.id == rhs.id
    }
}
