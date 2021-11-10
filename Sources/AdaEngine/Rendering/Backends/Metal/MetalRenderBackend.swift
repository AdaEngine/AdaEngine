//
//  MetalRenderBackend.swift
//  
//
//  Created by v.prusakov on 10/20/21.
//

#if canImport(Metal)
import Metal
import ModelIO
import MetalKit
import OrderedCollections

class MetalRenderBackend: RenderBackend {
    
    let context: Context
    var currentBuffer: Int = 0
    var currentBuffers: [MTLCommandBuffer] = []
    var maxFramesInFlight = 3
    
    var inFlightSemaphore: DispatchSemaphore!
    
    private var drawableList: DrawableList?
    private var cameraData: CameraData?
    
    init(appName: String) {
        self.context = Context()
    }
    
    var viewportSize: Vector2i {
        let viewport = self.context.viewport
        return Vector2i(Int(viewport.width), Int(viewport.height))
    }
    
    func createWindow(for view: RenderView, size: Vector2i) throws {
        let mtlView = (view as! MetalView)
        try self.context.createWindow(for: mtlView)
        
        self.inFlightSemaphore = DispatchSemaphore(value: self.maxFramesInFlight)
    }
    
    func resizeWindow(newSize: Vector2i) throws {
        self.context.windowUpdateSize(newSize)
    }
    
    func beginFrame() throws {
        
        self.inFlightSemaphore.wait()
        
        self.currentBuffer = (currentBuffer + 1) % maxFramesInFlight
        
        let commandBuffer = self.context.commandQueue.makeCommandBuffer()!
        defer {
            commandBuffer.commit()
        }
        guard let renderPass = self.context.view.currentRenderPassDescriptor else { return }
        
        var uniform = Uniforms()
        uniform.projectionMatrix = cameraData?.projection ?? .identity
        uniform.viewMatrix = cameraData?.view ?? .identity
        
        try self.drawableList?.drawables.forEach { drawable in
            guard drawable.isVisible else { return }
            
            try self.drawDrawable(drawable, commandBuffer: commandBuffer, descriptor: renderPass, uniform: uniform)
        }
        
        commandBuffer.present(self.context.view.currentDrawable!)
        
        commandBuffer.addCompletedHandler { _ in
            self.inFlightSemaphore.signal()
        }
    }
    
    func endFrame() throws {
        self.cameraData = nil
        self.drawableList = nil
    }
    
    func sync() {
        
    }
    
    // MARK: - Drawable
    
    func renderDrawableList(_ list: DrawableList, camera: CameraData) {
        self.drawableList = list
    }
    
    func makePipelineDescriptor(for material: Material, vertexDescriptor: MeshVertexDescriptor?) throws -> Any {
        let defaultLibrary = try context.device.makeDefaultLibrary(bundle: .module)
        let vertexFunc = defaultLibrary.makeFunction(name: "vertex_main")
        let fragmentFunc = defaultLibrary.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.vertexDescriptor = try vertexDescriptor?.makeMTKVertexDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let state = try self.context.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        return state
    }
    
    // MARK: - Buffers
    
    func makeBuffer(length: Int, options: UInt) -> RenderBuffer {
        let buffer = self.context.device.makeBuffer(length: length, options: MTLResourceOptions(rawValue: options))!
        return MetalBuffer(buffer)
    }
    
    func makeBuffer(bytes: UnsafeRawPointer, length: Int, options: UInt) -> RenderBuffer {
        let buffer = self.context.device.makeBuffer(bytes: bytes, length: length, options: MTLResourceOptions(rawValue: options))!
        
        return MetalBuffer(buffer)
    }
    
}

extension MetalRenderBackend {
    func drawDrawable(
        _ drawable: Drawable,
        commandBuffer: MTLCommandBuffer,
        descriptor: MTLRenderPassDescriptor,
        uniform: Uniforms
    ) throws {
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        defer {
            encoder?.endEncoding()
        }
        
        var uniform = uniform
        
        switch drawable.source {
        case .mesh(let mesh):
            guard let pipelineState = drawable.pipelineState as? MTLRenderPipelineState else { return }
            encoder?.setRenderPipelineState(pipelineState)
            
            uniform.modelMatrix = drawable.transform
            
            encoder?.setTriangleFillMode(.lines)
            
            for model in mesh.models {
                encoder?.setVertexBuffer(model.vertexBuffer.get(), offset: 0, index: 0)
                encoder?.setVertexBytes(&uniform, length: MemoryLayout<Uniforms>.stride, index: 1)
                
                encoder?.drawPrimitives(
                    type: .triangle,
                    vertexStart: 0,
                    vertexCount: model.vertexCount
                )
                
                for surface in model.surfaces {
                    encoder?.drawIndexedPrimitives(
                        type: surface.primitiveType.metal,
                        indexCount: surface.indexCount,
                        indexType: .uint32,
                        indexBuffer: surface.indexBuffer.get()!,
                        indexBufferOffset: 0)
                }
            }
            
            
        case .light:
            encoder?.setRenderPipelineState(drawable.pipelineState as! MTLRenderPipelineState)
            break
        case .empty:
            break
        }
        
    }
    
    func drawMesh(for drawable: Drawable, encoder: MTLRenderCommandEncoder) {
        
    }
}

extension MetalRenderBackend {
    
    final class Context {
        
        weak var view: MetalView!
        
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var viewport: MTLViewport = MTLViewport()
        var pipelineState: MTLRenderPipelineState!
        
        // MARK: - Methods
        
        func createWindow(for view: MetalView) throws {
            
            self.view = view
            
            self.viewport = MTLViewport(originX: 0, originY: 0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: 0, zfar: 1)
            
            self.device = self.prefferedDevice(for: view)
            view.device = self.device
            
            
            self.commandQueue = self.device.makeCommandQueue()
        }
        
        func prefferedDevice(for view: MetalView) -> MTLDevice {
            return view.preferredDevice ?? MTLCreateSystemDefaultDevice()!
        }
        
        func windowUpdateSize(_ size: Vector2i) {
            self.viewport = MTLViewport(originX: 0, originY: 0, width: Double(size.x), height: Double(size.y), znear: 0, zfar: 1)
        }
        
    }
}



#endif
