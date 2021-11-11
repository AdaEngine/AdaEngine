//
//  RequiredComponent.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

/// Get components from entity if exists.
/// Only works inside `Component` class.
@propertyWrapper public struct RequiredComponent<T: Component> {
    
    @available(*, unavailable, message: "RequiredComponents should call only inside `Component` classes.")
    public var wrappedValue: T {
        fatalError()
    }
    
    weak var storage: T?
    
    public init() { }
    
    // Currently private method to get parent component 
    public static subscript<EnclosingSelf: Component>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: KeyPath<EnclosingSelf, T>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) -> T {
        
        if let storage = object[keyPath: storageKeyPath].storage {
            return storage
        }
        
        let component: T! = object.components[T.self]
        object[keyPath: storageKeyPath].storage = component
        return component
    }
    
}
