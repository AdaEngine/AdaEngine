//
//  WorldPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

public protocol RenderWorldPlugin: Sendable {

    init()

    @RenderGraphActor
    func setup(in world: RenderWorld) async
}
