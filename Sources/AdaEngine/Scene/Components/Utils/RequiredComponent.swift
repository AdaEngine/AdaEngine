//
//  RequiredComponent.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

/// Get components from entity if exists.
/// Only works inside `Component` class.
@propertyWrapper
public struct RequiredComponent<T: Component> {
    
    @available(*, unavailable, message: "RequiredComponents should call only inside `Component` classes.")
    public var wrappedValue: T {
        fatalError()
    }
    
    public init() { }
    
    // Currently private method to get parent component 
    public static subscript<EnclosingSelf: ScriptComponent>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: KeyPath<EnclosingSelf, T>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) -> T {
        
        get {
            return object.components[T.self]!
        }
        
        set {
            object.components[T.self] = newValue
        }
        
    }
    
}
