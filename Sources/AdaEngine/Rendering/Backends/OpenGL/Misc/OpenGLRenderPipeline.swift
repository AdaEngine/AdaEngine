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

        if !self.program.isLinked() {
            var infoLogLength: GLint = 0
            glGetProgramiv(self.program.program, GLenum(GL_INFO_LOG_LENGTH), &infoLogLength)
            var infoLog = [GLchar](repeating: GLchar(0), count: Int(infoLogLength))
            glGetProgramInfoLog(self.program.program, GLsizei(infoLogLength), nil, &infoLog)
            assertionFailure("Program is not linked: \(String(cString: infoLog))")
        }

        self.program.validate()
    }
}
