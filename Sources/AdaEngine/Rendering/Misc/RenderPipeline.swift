//
//  RenderPipeline.swift
//  AdaEngine
//
//  Created by v.prusakov on 1/8/23.
//

protocol RenderPipeline {
    var descriptor: PipelineDescriptor { get }
}

public struct PipelineDescriptor {
    public var shader: ShaderDescriptor
    public var debugName: String = ""
    public var backfaceCulling: Bool = false
    public var primitive: IndexPrimitive = .triangle
    
    public init(shader: ShaderDescriptor) {
        self.shader = shader
    }
}
