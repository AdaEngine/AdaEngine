//
//  File.swift
//  
//
//  Created by v.prusakov on 8/13/21.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

#if os(macOS)
import AppKit

public typealias AView = NSView

#else
import UIKit

public typealias AView = UIView
#endif

import MetalKit

//public class MetalView: AView {
//    public override func makeBackingLayer() -> CALayer {
//        return CAMetalLayer()
//    }
//
//    public override var wantsUpdateLayer: Bool { return true }
//
//    public override init(frame frameRect: NSRect) {
//        super.init(frame: frameRect)
//        self.wantsLayer = true
//    }
//
//    public required init?(coder: NSCoder) {
//        fatalError()
//    }
//}


@objc public class MetalView: MTKView {

}

#endif
