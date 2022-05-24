//
//  iOSGameViewController.swift
//  
//
//  Created by v.prusakov on 5/24/22.
//

#if canImport(UIKit)
import UIKit
import MetalKit

class iOSGameViewController: UIViewController {
    var gameView: MetalView {
        return self.view as! MetalView
    }
    
    override func loadView() {
        self.view = MetalView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            let renderer = try RenderEngine.createRenderEngine(backendType: .metal, appName: "Ada")
            gameView.isPaused = true
            gameView.delegate = self
            
            let size = Size(
                width: Float(self.view.frame.size.width),
                height: Float(self.view.frame.size.height)
            )
            
            try renderer.initialize(for: gameView, size: size)
            
            gameView.isPaused = false
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
}

// MARK: - MTKViewDelegate

extension iOSGameViewController: MTKViewDelegate {
    
    func draw(in view: MTKView) {
        GameLoop.current.iterate()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        do {
            let size = Size(width: Float(size.width), height: Float(size.height))
            self.scene?.viewportSize = size
            try RenderEngine.shared.updateViewSize(newSize: size)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

#endif
