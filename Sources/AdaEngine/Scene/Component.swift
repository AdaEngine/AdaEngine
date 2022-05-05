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
    
    // MARK: - Codable
    
    public required convenience init(from decoder: Decoder) throws {
        self.init()
        let mirror = Mirror(reflecting: self)
        for (name, value) in mirror.children {
            
            guard var key = name else {
                continue
            }
            
            if key.hasPrefix("_") {
                key.remove(at: key.startIndex)
            }
            
            try (value as? _ExportCodable)?.initialize(from: decoder, key: CodingName(stringValue: key)!)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        let mirror = Mirror(reflecting: self)
        
        try encode(to: encoder, children: mirror.children)

        var superclass = mirror.superclassMirror
        while superclass != nil {
            try encode(to: encoder, children: superclass!.children)
            superclass = superclass?.superclassMirror
        }
    }
    
    func encode(to encoder: Encoder, children: Mirror.Children) throws {
        for (name, value) in children {
            guard let exportedValue = value as? _ExportCodable, var key = name else {
                continue
            }
            
            if key.hasPrefix("_") {
                key.remove(at: key.startIndex)
            }
            
            try exportedValue.encode(from: encoder, key: CodingName(stringValue: key)!)
        }
    }
    
}

extension Component: Codable {}

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
