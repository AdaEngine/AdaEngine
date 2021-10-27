//
//  File.swift
//  
//
//  Created by v.prusakov on 10/20/21.
//

#if canImport(Metal)
import Metal

class MetalRenderBackend: RenderBackend {
    
    let context: MetalContext
    var currentBuffer: Int = 0
    var maxFramesInFlight = 3
    
    var inFlightSemaphore: DispatchSemaphore!
    
    init(appName: String) {
        self.context = MetalContext()
    }
    
    func createWindow(for view: RenderView, size: Vector2i) throws {
        let mtlView = (view as! MetalView)
        try self.context.createWindow(for: mtlView)
        
        self.inFlightSemaphore = DispatchSemaphore(value: self.maxFramesInFlight)
    }
    
    func resizeWindow(newSize: Vector2i) throws {
        self.context.windowUpdateSize(newSize)
    }
    
    var transform = Transform.identity
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
        
        encoder?.setVertexBytes(vertecies, length: MemoryLayout<Vertex>.size * vertecies.count, index: 0)
        encoder?.setVertexBytes(&self.context.viewPort, length: MemoryLayout<MTLViewport>.size, index: 1)
        
        let projection: Transform = Transform.perspective(
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
        
        let indexBuffer = self.context.device.makeBuffer(bytes: indecies, length: MemoryLayout<UInt16>.size * indecies.count, options: .storageModeManaged)!
        
        encoder?.setVertexBytes(&uniform, length: MemoryLayout<Uniforms>.size, index: 2)
        
        encoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertecies.count)
        encoder?.drawIndexedPrimitives(type: .triangle, indexCount: indecies.count, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        
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
