//
//  Component.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

/// Base class describe some unit of game logic
open class Component {
    
    internal var isAwaked: Bool = false
    
    public internal(set) weak var entity: Entity?
    
    /// Called once when component is ready to use
    open func ready() {
        
    }
    
    /// Called each frame
    open func update(_ deltaTime: TimeInterval) {
        
    }
    
    /// Called each time with interval in seconds for physics and other updates.
    open func physicsUpdate(_ deltaTime: TimeInterval) {
        
    }
    
    /// Called once when component removed from entity
    open func destroy() {
        
    }
}

public extension Component {
    
    /// Get collection of components in entity
    /// - Warning: Crashed if component not connected to any entity.
    var components: Entity.ComponentSet {
        guard let entity = self.entity else {
            fatalError("Component not connected to any entity")
        }
        
        return entity.components
    }
    
    
    /// Set component to entity
    func setComponent<T: Component>(_ component: T) {
        self.entity?.components.set(component)
    }
}
