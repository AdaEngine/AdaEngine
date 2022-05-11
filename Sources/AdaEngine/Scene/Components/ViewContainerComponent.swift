//
//  ViewContainerComponent.swift
//  
//
//  Created by v.prusakov on 5/11/22.
//

@_exported import Math

public struct ViewContrainerComponent: Component {
    public var rootView: View
    
    public init(rootView: View) {
        self.rootView = rootView
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError()
    }
    
    public init(from decoder: Decoder) throws {
        fatalError()
    }
}

public struct Size: Equatable, Codable, Hashable {
    public var width: Float
    public var height: Float
    
    public static let zero = Size(width: 0, height: 0)
}

public struct Rect: Equatable, Codable, Hashable {
    public var offset: Vector2
    public var size: Size
    
    public static let zero = Rect(offset: .zero, size: .zero)
}
