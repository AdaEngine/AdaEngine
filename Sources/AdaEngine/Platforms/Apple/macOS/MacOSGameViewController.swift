//
//  MacOSGameViewController.swift
//  
//
//  Created by v.prusakov on 11/11/21.
//

#if canImport(AppKit)
import AppKit
import MetalKit
//
//final class MacOSGameViewController: NSViewController {
//
//    var gameView: MetalView {
//        return self.view as! MetalView
//    }
//
//    override func loadView() {
//        self.view = t MetalView()
//    }
//
////    override func viewDidLoad() {
////        super.viewDidLoad()
////
////        do {
////            RenderEngine.createRenderEngine(backendType: .metal, appName: "Ada")
////
////            gameView.isPaused = true
////            gameView.delegate = self
////
////            let size = Size(
////                width: Float(self.view.frame.size.width),
////                height: Float(self.view.frame.size.height)
////            )
////
////            try RenderEngine.shared.createWindow(<#T##windowId: Window.ID##Window.ID#>, for: gameView, size: size)
////
////            gameView.isPaused = false
////        } catch {
////            fatalError(error.localizedDescription)
////        }
////    }
//}
//
//// MARK: - MTKViewDelegate
//
//extension MacOSGameViewController: MTKViewDelegate {
//
//    func draw(in view: MTKView) {
//
//    }
//
//    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
//        do {
//            let size = Size(width: Float(size.width), height: Float(size.height))
//            try RenderEngine.shared.updateViewSize(newSize: size)
//        } catch {
//            fatalError(error.localizedDescription)
//        }
//    }
//}

#endif
