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
