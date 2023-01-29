//
//  Viewport.swift
//  
//
//  Created by v.prusakov on 1/22/23.
//

import Math

/// Viewport is an object where all draws happend.
public class Viewport: EventSource {
    
    public internal(set) weak var window: Window?
    
    internal private(set) var viewportRid: RID!
    
    var renderTargetTexture: RenderTexture {
        ViewportStorage.getRenderTexture(for: self) as! RenderTexture
    }
    
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
        
        defer {
            self.viewportRid = ViewportStorage.addViewport(self)
            ViewportStorage.viewportUpdateSize(textureSize, viewport: self)
        }
        
        self._viewportFrame = frame
    }
    
    deinit {
        ViewportStorage.removeViewport(self)
    }
    
    private func updateRenderTarget(with newSize: Size) {
        if self.size == newSize {
            return
        }
        
        let scale = window?.screen?.scale ?? 1.0
        let textureSize = Size(width: newSize.width * scale, height: newSize.height * scale)
        
        ViewportStorage.viewportUpdateSize(textureSize, viewport: self)
        EventManager.default.send(ViewportEvents.DidResize(size: newSize, viewport: self), source: self)
    }
    
    // MARK: EventSource
    
    public func subscribe<E>(to event: E.Type, on eventSource: EventSource?, completion: @escaping (E) -> Void) -> AnyCancellable where E : Event {
        EventManager.default.subscribe(to: event, on: eventSource ?? self, completion: completion)
    }
}

public enum ViewportEvents {
    public struct DidResize: Event {
        public let size: Size
        public let viewport: Viewport
    }
}
