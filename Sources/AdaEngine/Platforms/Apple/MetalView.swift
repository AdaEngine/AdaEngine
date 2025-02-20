//
//  MetalView.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/13/21.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

import MetalKit

open class MetalView: MTKView {
    
    public var windowID: UIWindow.ID
    
    #if MACOS
    var currentTrackingArea: NSTrackingArea?
    #endif
    
    public init(windowId: UIWindow.ID, frame: CGRect) {
        self.windowID = windowId
        super.init(frame: frame, device: nil)
    }
    
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

public extension CGRect {
    var toEngineRect: Rect {
        return Rect(origin: self.origin.toEnginePoint, size: self.size.toEngineSize)
    }
}

public extension CGPoint {
    var toEnginePoint: Point {
        return Point(x: Float(self.x), y: Float(self.y))
    }
}

public extension CGSize {
    var toEngineSize: Size {
        return Size(width: Float(self.width), height: Float(self.height))
    }
}

extension Size {
    var toCGSize: CGSize {
        return CGSize(width: Double(self.width), height: Double(self.height))
    }
}

extension Point {
    var toCGPoint: CGPoint {
        return CGPoint(x: Double(self.x), y: Double(self.y))
    }
}

#endif
