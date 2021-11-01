//
//  File.swift
//  
//
//  Created by v.prusakov on 10/20/21.
//

#if canImport(Metal)
import Metal
import ModelIO
import MetalKit

class MetalRenderBackend: RenderBackend {
    
    let context: MetalContext
    var currentBuffer: Int = 0
    var maxFramesInFlight = 3
    
    var inFlightSemaphore: DispatchSemaphore!
    
    var mesh: MTKMesh!
    
    init(appName: String) {
        self.context = MetalContext()
    }
    
    func createWindow(for view: RenderView, size: Vector2i) throws {
        let mtlView = (view as! MetalView)
        try self.context.createWindow(for: mtlView)
        
        self.inFlightSemaphore = DispatchSemaphore(value: self.maxFramesInFlight)
        
        let allocator = MTKMeshBufferAllocator(device: self.context.device)
        
        let mesh = MDLMesh(coneWithExtent: [1,1,1],
                              segments: [10, 10],
                              inwardNormals: false,
                              cap: true,
                              geometryType: .triangles,
                              allocator: allocator)
        
        self.mesh = try? MTKMesh(mesh: mesh, device: self.context.device)
    }
    
    func resizeWindow(newSize: Vector2i) throws {
        self.context.windowUpdateSize(newSize)
    }
    
    var transform = Transform3D.identity
    var radians: Float = 3
    
    func beginFrame() throws {
        
        self.inFlightSemaphore.wait()
        
        self.currentBuffer = (currentBuffer + 1) % maxFramesInFlight
        
        let commandBuffer = self.context.commandQueue.makeCommandBuffer()!
        defer {
            commandBuffer.commit()
        }
        guard let renderPass = self.context.view.currentRenderPassDescriptor else { return }
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)
        encoder?.setViewport(self.context.viewPort)
        encoder?.setRenderPipelineState(self.context.pipelineState)
        
        encoder?.setVertexBuffer(self.mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        
//        encoder?.setVertexBytes(vertecies, length: MemoryLayout<Vertex>.size * vertecies.count, index: 0)
        encoder?.setVertexBytes(&self.context.viewPort, length: MemoryLayout<MTLViewport>.size, index: 1)
        
        let projection: Transform3D = Transform3D.perspective(
            fieldOfView: Angle.radians(45),
            aspectRatio: Float(self.context.viewPort.width) / Float(self.context.viewPort.height),
            zNear: 0.1,
            zFar: 10
        )
        
        self.radians = radians + 1 * Time.deltaTime
        
        self.transform = transform.rotate(angle: .radians(self.radians), vector: Vector3(0, 0, 1))
        
        var uniform = Uniforms(
            modelMatrix: self.transform,
            viewMatrix: .lookAt(eye: Vector3(2, 2, 2), center: .one, up: Vector3(0, 0, 1)),
            projectionMatrix: projection
        )
        
        encoder?.setVertexBytes(&uniform, length: MemoryLayout<Uniforms>.size, index: 2)
        
        
        if let submesh = self.mesh.submeshes.first {
            encoder?.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)
        }
        
        encoder?.endEncoding()
        
        commandBuffer.present(self.context.view.currentDrawable!)
        
        commandBuffer.addCompletedHandler { _ in
            self.inFlightSemaphore.signal()
        }
        
    }
    
    func endFrame() throws {
        
    }
}

class MetalContext {
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    weak var view: MetalView!
    var viewPort: MTLViewport = .init()
    var pipelineState: MTLRenderPipelineState!
    
    init() {
        
    }
    
    func createWindow(for view: MetalView) throws {
        
        self.view = view
        
        self.viewPort = MTLViewport(originX: 0, originY: 0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: 0, zfar: 1)
        
        self.device = self.prefferedDevice(for: view)
        view.device = self.device
        let defaultLibrary = try self.device.makeDefaultLibrary(bundle: .module)
        let vertexFunc = defaultLibrary.makeFunction(name: "vertexFunction")
        let fragmentFunc = defaultLibrary.makeFunction(name: "fragmentFunction")
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        self.pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        
        self.commandQueue = self.device.makeCommandQueue()
    }
    
    func prefferedDevice(for view: MetalView) -> MTLDevice {
        return view.preferredDevice ?? MTLCreateSystemDefaultDevice()!
    }
    
    func windowUpdateSize(_ size: Vector2i) {
        self.viewPort = MTLViewport(originX: 0, originY: 0, width: Double(size.x), height: Double(size.y), znear: 0, zfar: 1)
    }
}

#endif
