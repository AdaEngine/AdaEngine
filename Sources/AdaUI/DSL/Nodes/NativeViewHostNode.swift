//
//  NativeViewHostNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.04.2026.
//

@_spi(Internal) import AdaInput
@_spi(Internal) import AdaRender
import AdaUtils
import Math

#if canImport(AppKit) || canImport(UIKit)

/// An internal protocol to unify AppKit and UIKit representables.
@MainActor
protocol NativeViewRepresentableInternal {
    func makeNativeView(context: NativeViewHostContext) -> Any
    func updateNativeView(_ view: Any, context: NativeViewHostContext)
    func sizeThatFits(_ proposal: ProposedViewSize, view: Any, context: NativeViewHostContext) -> Size
    func makeNativeCoordinator() -> Any
}

struct NativeViewHostContext {
    let environment: EnvironmentValues
    let coordinator: Any
}

#if canImport(AppKit) && os(macOS)
import AppKit

extension AppKitViewRepresentable {
    func makeNativeView(context: NativeViewHostContext) -> Any {
        let ctx = AppKitViewRepresentableContext<Self>(
            environment: context.environment,
            coordinator: context.coordinator as! Coordinator
        )
        return self.makeNSView(context: ctx)
    }

    func updateNativeView(_ view: Any, context: NativeViewHostContext) {
        let ctx = AppKitViewRepresentableContext<Self>(
            environment: context.environment,
            coordinator: context.coordinator as! Coordinator
        )
        self.updateNSView(view as! NSViewType, context: ctx)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, view: Any, context: NativeViewHostContext) -> Size {
        let ctx = AppKitViewRepresentableContext<Self>(
            environment: context.environment,
            coordinator: context.coordinator as! Coordinator
        )
        return self.sizeThatFits(proposal, nsView: view as! NSViewType, context: ctx)
    }

    func makeNativeCoordinator() -> Any {
        return (self as Self).makeCoordinator()
    }
}

extension AppKitViewRepresentableView: NativeViewRepresentableInternal {
    func makeNativeView(context: NativeViewHostContext) -> Any {
        representable.makeNativeView(context: context)
    }
    func updateNativeView(_ view: Any, context: NativeViewHostContext) {
        representable.updateNativeView(view, context: context)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, view: Any, context: NativeViewHostContext) -> Size {
        representable.sizeThatFits(proposal, view: view, context: context)
    }
    func makeNativeCoordinator() -> Any {
        representable.makeNativeCoordinator()
    }
}

#endif

#if canImport(UIKit) && (os(iOS) || os(tvOS) || os(visionOS))
import UIKit

extension UIKitViewRepresentable {
    func makeNativeView(context: NativeViewHostContext) -> Any {
        let ctx = UIKitViewRepresentableContext<Self>(
            environment: context.environment,
            coordinator: context.coordinator as! Coordinator
        )
        return self.makeUIView(context: ctx)
    }

    func updateNativeView(_ view: Any, context: NativeViewHostContext) {
        let ctx = UIKitViewRepresentableContext<Self>(
            environment: context.environment,
            coordinator: context.coordinator as! Coordinator
        )
        self.updateUIView(view as! UIViewType, in: ctx)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, view: Any, context: NativeViewHostContext) -> Size {
        let ctx = UIKitViewRepresentableContext<Self>(
            environment: context.environment,
            coordinator: context.coordinator as! Coordinator
        )
        return self.sizeThatFits(proposal, uiView: view as! UIViewType, context: ctx)
    }

    func makeNativeCoordinator() -> Any {
        return (self as Self).makeCoordinator()
    }
}

extension UIKitViewRepresentableView: NativeViewRepresentableInternal {
    func makeNativeView(context: NativeViewHostContext) -> Any {
        representable.makeNativeView(context: context)
    }
    func updateNativeView(_ view: Any, context: NativeViewHostContext) {
        representable.updateNativeView(view, context: context)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, view: Any, context: NativeViewHostContext) -> Size {
        representable.sizeThatFits(proposal, view: view, context: context)
    }
    func makeNativeCoordinator() -> Any {
        representable.makeNativeCoordinator()
    }
}

#endif

@MainActor
final class NativeViewHostNode: ViewNode {
    
    let representable: any NativeViewRepresentableInternal
    private var nativeView: Any?
    private var coordinator: Any?
    
    private var offscreenTexture: Texture2D?
    private var isOverlayAttached = false
    
    init<V: View>(representable: any NativeViewRepresentableInternal, content: V) {
        self.representable = representable
        super.init(content: content)
    }
    
    override func performLayout() {
        super.performLayout()
        
        if coordinator == nil {
            coordinator = representable.makeNativeCoordinator()
        }
        
        let context = NativeViewHostContext(environment: self.environment, coordinator: coordinator!)
        
        if nativeView == nil {
            nativeView = representable.makeNativeView(context: context)
        }
        
        representable.updateNativeView(nativeView!, context: context)
        
        let mode = environment.nativeRenderingMode
        switch mode {
        case .overlay:
            updateOverlay()
        case .offscreen:
            updateOffscreen()
        @unknown default:
            break
        }
    }
    
    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        if coordinator == nil {
            coordinator = representable.makeNativeCoordinator()
        }
        
        if nativeView == nil {
            let context = NativeViewHostContext(environment: self.environment, coordinator: coordinator!)
            nativeView = representable.makeNativeView(context: context)
        }
        
        let context = NativeViewHostContext(environment: self.environment, coordinator: coordinator!)
        return representable.sizeThatFits(proposal, view: nativeView!, context: context)
    }
    
    private func updateOverlay() {
        guard let nativeView = self.nativeView else { return }
        
        // Ensure offscreen resources are cleaned up
        self.offscreenTexture = nil
        
        guard let window = self.owner?.window, let systemWindow = window.systemWindow else {
            detachFromOverlay()
            return
        }
        
        #if canImport(AppKit) && os(macOS)
        if let nsWindow = systemWindow as? NSWindow, let metalView = nsWindow.contentView, let nsView = nativeView as? NSView {
            if nsView.superview != metalView {
                metalView.addSubview(nsView)
                isOverlayAttached = true
            }
            
            let absoluteFrame = self.absoluteFrame()
            // In AppKit, Y-axis is flipped compared to AdaUI (which uses top-left origin)
            let windowHeight = Float(nsWindow.contentRect(forFrameRect: nsWindow.frame).height)
            nsView.frame = NSRect(
                x: CGFloat(absoluteFrame.origin.x),
                y: CGFloat(windowHeight - absoluteFrame.origin.y - absoluteFrame.size.height),
                width: CGFloat(absoluteFrame.size.width),
                height: CGFloat(absoluteFrame.size.height)
            )
            
            // Clipping
            let visibleFrame = self.calculateVisibleFrame()
            if visibleFrame.size.width < absoluteFrame.size.width || visibleFrame.size.height < absoluteFrame.size.height {
                let maskLayer = CAShapeLayer()
                // Convert visible frame to local view coordinates
                let localVisibleFrame = Rect(
                    origin: Point(x: visibleFrame.origin.x - absoluteFrame.origin.x, y: visibleFrame.origin.y - absoluteFrame.origin.y),
                    size: visibleFrame.size
                )
                maskLayer.path = NSBezierPath(rect: localVisibleFrame.toCGRect).cgPath
                nsView.layer?.mask = maskLayer
            } else {
                nsView.layer?.mask = nil
            }
            
            nsView.isHidden = false
        }
        #elseif canImport(UIKit) && (os(iOS) || os(tvOS) || os(visionOS))
        if let uiView = nativeView as? UIView {
            // UIKit implementation
            if let parent = findUIKitParentView() {
                if uiView.superview != parent {
                    parent.addSubview(uiView)
                    isOverlayAttached = true
                }
                let absoluteFrame = self.absoluteFrame()
                uiView.frame = CGRect(
                    x: CGFloat(absoluteFrame.origin.x),
                    y: CGFloat(absoluteFrame.origin.y),
                    width: CGFloat(absoluteFrame.size.width),
                    height: CGFloat(absoluteFrame.size.height)
                )

                // Clipping
                let visibleFrame = self.calculateVisibleFrame()
                if visibleFrame.size.width < absoluteFrame.size.width || visibleFrame.size.height < absoluteFrame.size.height {
                    let maskView = UIView()
                    let localVisibleFrame = Rect(
                        origin: Point(x: visibleFrame.origin.x - absoluteFrame.origin.x, y: visibleFrame.origin.y - absoluteFrame.origin.y),
                        size: visibleFrame.size
                    )
                    maskView.frame = localVisibleFrame.toCGRect
                    maskView.backgroundColor = .black
                    uiView.mask = maskView
                } else {
                    uiView.mask = nil
                }

                uiView.isHidden = false
            }
        }
        #endif
    }
    
    private func detachFromOverlay() {
        guard isOverlayAttached, let nativeView = self.nativeView else { return }
        
        #if canImport(AppKit) && os(macOS)
        if let nsView = nativeView as? NSView {
            nsView.removeFromSuperview()
        }
        #elseif canImport(UIKit) && (os(iOS) || os(tvOS) || os(visionOS))
        if let uiView = nativeView as? UIView {
            uiView.removeFromSuperview()
        }
        #endif
        
        isOverlayAttached = false
    }
    
    private func updateOffscreen() {
        detachFromOverlay()
    }
    
    #if canImport(UIKit) && (os(iOS) || os(tvOS) || os(visionOS))
    private func findUIKitParentView() -> UIView? {
        return nil // To be implemented
    }
    #endif
    
    override func hitTest(_ point: Point, with event: any InputEvent) -> ViewNode? {
        if self.point(inside: point, with: event) {
            return self
        }
        return nil
    }
    
    override func point(inside point: Point, with event: any InputEvent) -> Bool {
        return point.x >= 0 && point.y >= 0 && point.x <= frame.width && point.y <= frame.height
    }
    
    override func onMouseEvent(_ event: MouseEvent) {
        if environment.nativeRenderingMode == .offscreen {
            if event.button == .scrollWheel {
                forwardScrollEvent(event)
            } else {
                forwardMouseEvent(event)
            }
        }
    }
    
    private func forwardMouseEvent(_ event: MouseEvent) {
        guard let nativeView = self.nativeView else { return }
        
        let absoluteOrigin = self.absoluteFrame().origin
        let localPoint = Point(
            x: event.mousePosition.x - absoluteOrigin.x,
            y: event.mousePosition.y - absoluteOrigin.y
        )
        
        #if canImport(AppKit) && os(macOS)
        if let nsView = nativeView as? NSView, let window = nsView.window {
            let timestamp = ProcessInfo.processInfo.systemUptime
            let eventType: NSEvent.EventType
            
            switch event.phase {
            case .began: 
                eventType = .leftMouseDown
            case .changed: 
                eventType = .leftMouseDragged
            case .ended: 
                eventType = .leftMouseUp
            case .cancelled: 
                return
            }
            
            let windowPoint = NSPoint(x: CGFloat(localPoint.x), y: CGFloat(nsView.bounds.height - CGFloat(localPoint.y)))
            
            if let nsEvent = NSEvent.mouseEvent(
                with: eventType,
                location: windowPoint,
                modifierFlags: [],
                timestamp: timestamp,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: event.phase == .ended ? 0.0 : 1.0
            ) {
                switch eventType {
                case .leftMouseDown: nsView.mouseDown(with: nsEvent)
                case .leftMouseUp: nsView.mouseUp(with: nsEvent)
                case .leftMouseDragged: nsView.mouseDragged(with: nsEvent)
                default: break
                }
            }
        }
        #endif
    }
    
    private func forwardScrollEvent(_ event: MouseEvent) {
        #if canImport(AppKit) && os(macOS)
        guard let nsView = nativeView as? NSView, let window = nsView.window else { return }
        
        let absoluteOrigin = self.absoluteFrame().origin
        let localPoint = Point(
            x: event.mousePosition.x - absoluteOrigin.x,
            y: event.mousePosition.y - absoluteOrigin.y
        )
        let windowPoint = NSPoint(x: CGFloat(localPoint.x), y: CGFloat(nsView.bounds.height - CGFloat(localPoint.y)))
        
        if let cgEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(event.scrollDelta.y),
            wheel2: Int32(event.scrollDelta.x),
            wheel3: 0
        ) {
            cgEvent.location = window.convertPoint(toScreen: windowPoint)
            if let nsEvent = NSEvent(cgEvent: cgEvent) {
                nsView.scrollWheel(with: nsEvent)
            }
        }
        #endif
    }
    
    override func onTouchesEvent(_ touches: Set<TouchEvent>) {
        if environment.nativeRenderingMode == .offscreen {
            forwardTouchesEvent(touches)
        }
    }
    
    private func forwardTouchesEvent(_ touches: Set<TouchEvent>) {
        #if canImport(UIKit) && (os(iOS) || os(tvOS) || os(visionOS))
        guard let uiView = nativeView as? UIView else { return }
        
        // Very basic scroll support for offscreen UIKit
        if let scrollView = findScrollView(in: uiView) {
            for touch in touches {
                if touch.phase == .changed {
                    let deltaX = touch.position.x - touch.previousPosition.x
                    let deltaY = touch.position.y - touch.previousPosition.y
                    
                    var offset = scrollView.contentOffset
                    offset.x -= CGFloat(deltaX)
                    offset.y -= CGFloat(deltaY)
                    
                    scrollView.setContentOffset(offset, animated: false)
                }
            }
        }
        
        // Simple tap simulation for offscreen
        for touch in touches {
            if touch.phase == .ended {
                let absoluteOrigin = self.absoluteFrame().origin
                let localPoint = CGPoint(
                    x: CGFloat(touch.position.x - absoluteOrigin.x),
                    y: CGFloat(touch.position.y - absoluteOrigin.y)
                )
                
                if let hitView = uiView.hitTest(localPoint, with: nil) {
                    // Try to trigger actions if it's a control
                    if let control = hitView as? UIControl {
                        control.sendActions(for: .touchUpInside)
                    }
                }
            }
        }
        #endif
    }

    #if canImport(UIKit) && (os(iOS) || os(tvOS) || os(visionOS))
    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        return nil
    }
    #endif
    
    override func draw(with context: UIGraphicsContext) {
        if environment.nativeRenderingMode == .offscreen {
            if let texture = offscreenTexture {
                var context = context
                context.translateBy(x: self.frame.origin.x, y: -self.frame.origin.y)
                let rect = Rect(origin: .zero, size: frame.size)
                context.drawRect(rect, texture: texture, color: .white)
            }
        }
    }
    
    override func update(_ deltaTime: AdaUtils.TimeInterval) {
        if environment.nativeRenderingMode == .offscreen {
            renderOffscreen()
        } else if environment.nativeRenderingMode == .overlay {
            updateOverlay()
        }
    }
    
    private func renderOffscreen() {
        guard let nativeView = self.nativeView else { return }
        
        let size = self.frame.size
        if size.width <= 0 || size.height <= 0 { return }
        
        let scale = max(environment.scaleFactor, 1)
        let pixelSize = SizeInt(
            width: Int(size.width * scale),
            height: Int(size.height * scale)
        )
        
        if offscreenTexture == nil || offscreenTexture!.width != pixelSize.width || offscreenTexture!.height != pixelSize.height {
            let descriptor = TextureDescriptor(
                width: pixelSize.width,
                height: pixelSize.height,
                pixelFormat: .rgba8,
                textureUsage: [.read, .write],
                textureType: .texture2D
            )
            self.offscreenTexture = Texture2D(descriptor: descriptor)
        }
        
        guard let texture = offscreenTexture else { return }
        
        #if canImport(AppKit) && os(macOS)
        if let nsView = nativeView as? NSView {
            let width = pixelSize.width
            let height = pixelSize.height
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return }
            
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: CGFloat(scale), y: CGFloat(-scale))
            
            if let layer = nsView.layer {
                layer.render(in: context)
            } else {
                let prevContext = NSGraphicsContext.current
                NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
                nsView.displayIgnoringOpacity(nsView.bounds)
                NSGraphicsContext.current = prevContext
            }
            
            if let data = context.data {
                texture.replaceRegion(
                    RectInt(origin: .zero, size: pixelSize),
                    withBytes: data,
                    bytesPerRow: width * 4
                )
            }
        }
        #elseif canImport(UIKit) && (os(iOS) || os(tvOS) || os(visionOS))
        if let uiView = nativeView as? UIView {
            let width = pixelSize.width
            let height = pixelSize.height
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return }
            
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: CGFloat(scale), y: CGFloat(-scale))
            
            uiView.layer.render(in: context)
            
            if let data = context.data {
                texture.replaceRegion(
                    RectInt(origin: .zero, size: pixelSize),
                    withBytes: data,
                    bytesPerRow: width * 4
                )
            }
        }
        #endif
    }
}

#endif
