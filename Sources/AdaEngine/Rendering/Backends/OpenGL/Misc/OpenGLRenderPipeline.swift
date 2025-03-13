//
//  OpenGLRenderPipeline.swift
//  AdaEngine
//
//  Created by vladislav.prusakov on 13.03.2025.
//

#if WASM
import WebGL
#endif
#if DARWIN
import OpenGL.GL3
#else
import OpenGL
#endif

final class OpenGLRenderPipeline: RenderPipeline {
    let descriptor: RenderPipelineDescriptor
    let program: OpenGLProgram

    init(descriptor: RenderPipelineDescriptor) {
        self.descriptor = descriptor
        self.program = OpenGLProgram()

        self.program.attach(to: descriptor.vertex.compiledShader as! OpenGLShader)
        self.program.attach(to: descriptor.fragment.compiledShader as! OpenGLShader)
        self.program.link()
    }
}
