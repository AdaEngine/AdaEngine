//
//  Entity+ComponentSet.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

import Collections

public extension Entity {
    
    /// Hold entity components
    @frozen struct ComponentSet: Codable {
        
        internal weak var entity: Entity?
        
        var world: World? {
            return self.entity?.scene?.world
        }
        
        private(set) var buffer: [UInt: Component]
        
        // MARK: - Codable
        
        init() {
            self.buffer = [:]
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingName.self)
            var buffer: [UInt: Component] = [:]
            
//            for key in container.allKeys {
//                guard let type = ComponentStorage.getRegistredComponent(for: key.stringValue) else {
//                    continue
//                }
//
//                let component = try type.init(from: container.superDecoder(forKey: key))
//
//                buffer[ObjectIdentifier(type)] = component
//            }
            
            self.buffer = buffer
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingName.self)
            
//            for (_, value) in self.buffer {
//                let superEncoder = container.superEncoder(forKey: CodingName(stringValue: type(of: value).swiftName))
//                try value.encode(to: superEncoder)
//            }
        }

        /// Gets or sets the component of the specified type.
        public subscript<T>(componentType: T.Type) -> T? where T : Component {
            get {
                return buffer[T.identifier] as? T
            }
            
            set {
                self.buffer[T.identifier] = newValue
                (newValue as? ScriptComponent)?.entity = entity
                
                guard let ent = self.entity else {
                    return
                }
                
                if let component = newValue {
                    self.world?.entity(ent, didAddComponent: component, with: T.identifier)
                } else {
                    self.world?.entity(ent, didRemoveComponent: T.self, with: T.identifier)
                }
            }
        }

        public mutating func set<T>(_ component: T) where T : Component {
            self.buffer[T.identifier] = component
            (component as? ScriptComponent)?.entity = self.entity
            
            if let ent = self.entity {
                self.world?.entity(ent, didAddComponent: component, with: T.identifier)
            }
        }

        public mutating func set(_ components: [Component]) {
            for component in components {
                
                let componentType = type(of: component)
                
                self.buffer[componentType.identifier] = component
                (component as? ScriptComponent)?.entity = self.entity
                
                if let ent = self.entity {
                    self.world?.entity(ent, didAddComponent: component , with: componentType.identifier)
                }
            }
        }

        /// Returns `true` if the collections contains a component of the specified type.
        public func has(_ componentType: Component.Type) -> Bool {
            return self.buffer[componentType.identifier] != nil
        }

        /// Removes the component of the specified type from the collection.
        public mutating func remove(_ componentType: Component.Type) {
            (self.buffer[componentType.identifier] as? ScriptComponent)?.destroy()
            self.buffer[componentType.identifier] = nil
            
            if let ent = self.entity {
                self.world?.entity(ent, didRemoveComponent: componentType, with: componentType.identifier)
            }
        }
        
        /// The number of components in the set.
        public var count: Int {
            return self.buffer.count
        }
        
        /// A Boolean value indicating whether the set is empty.
        public var isEmpty: Bool {
            return self.buffer.isEmpty
        }
    }
}

// swiftlint:disable identifier_name

public extension Entity.ComponentSet {
    /// Gets the components of the specified types.
    subscript<A, B>(_ a: A.Type, _ b: B.Type) -> (A, B) where A : Component, B: Component {
        return (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B
        )
    }
    
    /// Gets the components of the specified types.
    subscript<A, B, C>(_ a: A.Type, _ b: B.Type, _ c: C.Type) -> (A, B, C) where A : Component, B: Component, C: Component {
        return (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B,
            buffer[c.identifier] as! C
        )
    }
    
    /// Gets the components of the specified types.
    subscript<A, B, C, D>(_ a: A.Type, _ b: B.Type, _ c: C.Type, _ d: D.Type) -> (A, B, C, D) where A : Component, B: Component, C: Component, D: Component {
        return (
            buffer[a.identifier] as! A,
            buffer[b.identifier] as! B,
            buffer[c.identifier] as! C,
            buffer[d.identifier] as! D
        )
    }
}

public extension Entity.ComponentSet {
    static func += <T: Component>(lhs: inout Self, rhs: T) {
        lhs[T.self] = rhs
    }
}

extension Entity.ComponentSet: CustomStringConvertible {
    public var description: String {
        let result = self.buffer.reduce("") { partialResult, value in
            let name = type(of: value.value)
            return partialResult + "\n   ⟐ \(name)"
        }
        
        return "ComponentSet(entity: \(self.entity?.name ?? "\'\'"),\(result)\n)"
    }
}

// swiftlint:enable identifier_name
