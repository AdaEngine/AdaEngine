//
//  View+Observable.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 06.07.2024.
//

@preconcurrency import Observation

// https://github.com/swiftlang/swift/pull/77890#issuecomment-2645596313
// FIXME: This is a little hack to avoid crash 
#if os(Android) || os(Linux)
@_cdecl("_ZN5swift9threading5fatalEPKcz")
func swiftThreadingFatal() { }
#endif

public extension View {

    /// Places an observable object in the view's environment.
    ///
    /// - Parameter object: The object to set for this object's type in the
    ///   environment, or `nil` to clear an object of this type from the
    ///   environment.
    ///
    /// - Returns: A view that has the specified object in its environment.
    func environment<T: Observable & AnyObject>(_ object: T?) -> some View {
        self.transformEnvironment(\.observableStorage) { storage in
            storage.insertValue(object)
        }
    }
}

struct ObservableStorageEnvironment: Sendable {
    private var storedValues: [ObjectIdentifier: any Observable] = [:]

    mutating func insertValue<T: Observable & AnyObject>(_ value: T?) {
        storedValues[ObjectIdentifier(T.self)] = value
    }

    func getValue<T: Observable & AnyObject>(_ type: T.Type) -> T {
        guard let value = storedValues[ObjectIdentifier(T.self)] else {
            fatalError("Can't find object in view environment with type \(type)")
        }

        return value as! T
    }
}

extension EnvironmentValues {
    @Entry var observableStorage: ObservableStorageEnvironment = ObservableStorageEnvironment()
}
