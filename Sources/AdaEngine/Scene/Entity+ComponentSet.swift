//
//  Entity+ComponentSet.swift
//  
//
//  Created by v.prusakov on 5/6/22.
//

import Foundation
import Collections

public extension Entity {
    
    @frozen
    struct ComponentSet: Codable {
        
        internal weak var entity: Entity?
        
        // TODO: looks like not efficient solution
        private(set) var buffer: OrderedDictionary<String, Component>
        
        // MARK: - Codable
        
        init() {
            self.buffer = [:]
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingName.self)
            
            var buffer: OrderedDictionary<String, Component> = [:]
            
            for key in container.allKeys {
                guard let type = ComponentStorage.getRegistredComponent(for: key.stringValue) else {
                    continue
                }
                
                let component = try type.init(from: container.superDecoder(forKey: key))
                
                buffer[key.stringValue] = component
            }
            
            self.buffer = buffer
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingName.self)
            
            for (token, value) in self.buffer {
                let superEncoder = container.superEncoder(forKey: CodingName(stringValue: token))
                try value.encode(to: superEncoder)
            }
        }

        /// Gets or sets the component of the specified type.
        public subscript<T>(componentType: T.Type) -> T? where T : Component {
            get {
                let identifier = componentType.swiftName
                return buffer[identifier] as? T
            }
            
            set {
                let identifier = componentType.swiftName
                self.buffer[identifier] = newValue
                
                (newValue as? ScriptComponent)?.entity = entity
            }
        }

        public mutating func set<T>(_ component: T) where T : Component {
            let identifier = type(of: component).swiftName
            self.buffer[identifier] = component
            (component as? ScriptComponent)?.entity = self.entity
        }

        public mutating func set(_ components: [Component]) {
            for component in components {
                let identifier = type(of: component).swiftName
                self.buffer[identifier] = component
                (component as? ScriptComponent)?.entity = self.entity
            }
        }

        /// Returns `true` if the collections contains a component of the specified type.
        public func has(_ componentType: Component.Type) -> Bool {
            return self.buffer[componentType.swiftName] != nil
        }

        /// Removes the component of the specified type from the collection.
        public mutating func remove(_ componentType: Component.Type) {
            let identifier = componentType.swiftName
            (self.buffer[identifier] as? ScriptComponent)?.destroy()
            self.buffer[identifier] = nil
        }

        /// Removes all components from the collection.
        public mutating func removeAll() {
            self.buffer.forEach { ($0.value as? ScriptComponent)?.destroy() }
            
            self.buffer.removeAll()
        }

        /// The number of components in this collection.
        public var count: Int {
            return self.buffer.count
        }
        
        public var isEmpty: Bool {
            return self.buffer.isEmpty
        }
    }
}
