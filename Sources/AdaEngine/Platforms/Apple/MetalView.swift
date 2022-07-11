//
//  MetalView.swift
//  
//
//  Created by v.prusakov on 8/13/21.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

import MetalKit

public final class MetalView: MTKView {
    
    let windowID: Window.ID
    
    #if os(macOS)
    var currentTrackingArea: NSTrackingArea?
    #endif
    
    init(windowId: Window.ID, frame: CGRect) {
        self.windowID = windowId
        super.init(frame: frame, device: nil)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension CGRect {
    var toEngineRect: Rect {
        return Rect(origin: self.origin.toEnginePoint, size: self.size.toEngineSize)
    }
}

extension CGPoint {
    var toEnginePoint: Point {
        return Point(x: Float(self.x), y: Float(self.y))
    }
}

extension CGSize {
    var toEngineSize: Size {
        return Size(width: Float(self.width), height: Float(self.height))
    }
}

#endif
