//
//  MetalView.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/13/21.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import AdaUI
import Math
import MetalKit
import QuartzCore
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

open class MetalView: MTKView {
    
    public var windowID: AdaUI.UIWindow.ID
    var allowsTransparency: Bool = false {
        didSet {
            if oldValue != allowsTransparency {
                updateDrawableMetrics()
            }
        }
    }
    weak var windowManager: UIWindowManager?

    #if MACOS
    var currentTrackingArea: NSTrackingArea?
    var passthroughLocalMouseMonitor: Any?
    var passthroughGlobalMouseMonitor: Any?
    #endif

    #if canImport(UIKit)
    var showsKeyboard: Bool = false
    #endif

    #if MACOS
    open override var isOpaque: Bool {
        !allowsTransparency
    }
    #endif

    public init(windowId: AdaUI.UIWindow.ID, frame: CGRect) {
        self.windowID = windowId
        super.init(frame: frame, device: nil)
        #if canImport(UIKit)
        self.isOpaque = true
        #endif
        self.isPaused = true
        self.enableSetNeedsDisplay = false
        self.autoResizeDrawable = true
        self.presentsWithTransaction = false
        updateDrawableMetrics()
    }
    
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if canImport(UIKit)
    open override func layoutSubviews() {
        super.layoutSubviews()
        updateDrawableMetrics()
    }
    #endif

    #if canImport(AppKit)
    open override func layout() {
        super.layout()
        updateDrawableMetrics()
    }

    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateDrawableMetrics()
        updateMousePassthroughMonitoring()
    }

    open override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableMetrics()
    }
    #endif

    @discardableResult
    func updateDrawableMetrics() -> CGSize {
        #if canImport(UIKit)
        let scale = self.window?.screen.scale ?? UIScreen.main.scale
        self.contentScaleFactor = scale
        self.layer.contentsScale = scale
        #elseif canImport(AppKit)
        let scale = unsafe appKitBackingScaleFactor(for: self.window)
        self.layer?.contentsScale = scale
        #endif

        let drawableSize = CGSize(
            width: ceil(bounds.width * scale),
            height: ceil(bounds.height * scale)
        )

        guard drawableSize.width > 0, drawableSize.height > 0 else {
            if let metalLayer = self.layer as? CAMetalLayer {
                metalLayer.isOpaque = !allowsTransparency
                metalLayer.frame = bounds
                metalLayer.contentsScale = scale
            }
            return drawableSize
        }

        self.drawableSize = drawableSize

        if let metalLayer = self.layer as? CAMetalLayer {
            metalLayer.isOpaque = !allowsTransparency
            metalLayer.frame = bounds
            metalLayer.contentsScale = scale
            metalLayer.drawableSize = drawableSize
        }

        return drawableSize
    }
    
}

#if canImport(AppKit)
@MainActor
private func appKitBackingScaleFactor(for window: NSWindow?) -> CGFloat {
    guard let window else {
        return NSScreen.main?.backingScaleFactor ?? NSScreen.screens.first?.backingScaleFactor ?? 1
    }

    return window.screen?.backingScaleFactor
        ?? appKitScreen(containing: window.frame)?.backingScaleFactor
        ?? window.backingScaleFactor
}

private func appKitScreen(containing windowFrame: NSRect) -> NSScreen? {
    let screens = NSScreen.screens
    guard !screens.isEmpty else {
        return nil
    }

    let bestMatch = screens
        .map { screen in (screen, screen.frame.intersectionArea(with: windowFrame)) }
        .max { lhs, rhs in lhs.1 < rhs.1 }

    guard let bestMatch, bestMatch.1 > 0 else {
        return nil
    }

    return bestMatch.0
}

private extension NSRect {
    func intersectionArea(with rect: NSRect) -> CGFloat {
        let intersection = self.intersection(rect)
        guard !intersection.isNull, !intersection.isEmpty else {
            return 0
        }

        return intersection.width * intersection.height
    }
}
#endif

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
