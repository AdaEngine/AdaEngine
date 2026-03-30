import Foundation

public enum RuntimeTypeRegistry {
    public static func componentType(named name: String) -> (any Component.Type)? {
        ComponentStorage.getRegisteredComponent(for: name)
    }

    public static func resourceType(named name: String) -> (any Resource.Type)? {
        ResourceStorage.getRegisteredResource(for: name)
    }

    public static func registeredComponentTypes() -> [String: any Component.Type] {
        ComponentStorage.allRegisteredComponents()
    }

    public static func registeredResourceTypes() -> [String: any Resource.Type] {
        ResourceStorage.allRegisteredResources()
    }
}
