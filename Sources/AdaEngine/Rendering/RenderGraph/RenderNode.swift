//
//  RenderNode.swift
//  
//
//  Created by v.prusakov on 2/18/23.
//

public protocol RenderNode {
    
    typealias Context = RenderGraphContext
    
    var inputResources: [RenderSlot] { get }
    var outputResources: [RenderSlot] { get }
    
    func execute(context: Context) throws -> [RenderSlotValue]
}

public extension RenderNode {
    var inputResources: [RenderSlot] {
        return []
    }
    
    var outputResources: [RenderSlot] {
        return []
    }
}
