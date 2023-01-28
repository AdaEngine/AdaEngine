//
//  Viewport.swift
//  
//
//  Created by v.prusakov on 1/22/23.
//

import Math

// A texture using as render target.
public class RenderTexture: Texture2D {
    
    public let pixelFormat: PixelFormat
    
    public private(set) var isActive: Bool = true
    
    init(size: Size, format: PixelFormat) {
        let descriptor = TextureDescriptor(
            width: Int(size.width),
            height: Int(size.height),
            pixelFormat: format,
            textureUsage: [.renderTarget, .read],
            textureType: .texture2D
        )
        
        self.pixelFormat = format
        
        let rid = RenderEngine.shared.makeTexture(from: descriptor)
        
        super.init(rid: rid, size: size)
    }
    
    public required init(asset decoder: AssetDecoder) throws {
        fatalError("init(asset:) has not been implemented")
    }
    
    public convenience required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    func setActive(_ isActive: Bool) {
        self.isActive = isActive
    }
}

/// Viewport is an object where all draws happend.
public class Viewport: EventSource {
    
    public internal(set) var renderTexture: RenderTexture
    
    // TODO: (Vlad) should we have depth texture?
    public internal(set) var depthTexture: RenderTexture
    
    public internal(set) weak var window: Window?
    
    internal private(set) var viewportRid: RID!
    
    public var isVisible = true
    
    public var position: Point {
        get {
            return _viewportFrame.origin
        }
        
        set {
            _viewportFrame.origin = newValue
        }
    }
    
    public var size: Size {
        get {
            return _viewportFrame.size
        }
        
        set {
            self.updateRenderTarget(with: newValue)
            self._viewportFrame.size = newValue
        }
    }
    
    private var _viewportFrame: Rect
    
    internal weak var camera: Camera?
    
    public init(frame: Rect) {
        let textureSize = Size(width: frame.size.width, height: frame.size.height)
        self.renderTexture = RenderTexture(size: textureSize, format: .bgra8)
        self.depthTexture = RenderTexture(size: textureSize, format: .depth_32f_stencil8)
        
        defer {
            self.viewportRid = ViewportRenderer.shared.addViewport(self)
        }
        
        self._viewportFrame = frame
    }
    
    deinit {
        ViewportRenderer.shared.removeViewport(self)
    }
    
    private func updateRenderTarget(with newSize: Size) {
        if self.size == newSize {
            return
        }
        
        let scale = window?.screen?.scale ?? 1.0
        let textureSize = Size(width: newSize.width * scale, height: newSize.height * scale)
        
        self.renderTexture.setActive(false)
        self.depthTexture.setActive(false)
        
        self.renderTexture = RenderTexture(size: textureSize, format: .bgra8)
        self.depthTexture = RenderTexture(size: textureSize, format: .depth_32f_stencil8)
        
        EventManager.default.send(ViewportEvents.DidResize(size: newSize, viewport: self), source: self)
    }
    
    // MARK: EventSource
    
    public func subscribe<E>(to event: E.Type, on eventSource: EventSource?, completion: @escaping (E) -> Void) -> Cancellable where E : Event {
        EventManager.default.subscribe(to: event, on: eventSource ?? self, completion: completion)
    }
}

public enum ViewportEvents {
    public struct DidResize: Event {
        public let size: Size
        public let viewport: Viewport
    }
}
