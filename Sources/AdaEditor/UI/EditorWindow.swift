//
//  EditorWindow.swift
//  
//
//  Created by v.prusakov on 5/31/22.
//

import AdaEngine

class EditorWindow: Window {
    override func windowDidReady() {
        self.title = "Ada Editor"
        
        self.canDraw = true
//        
//        let blueView = View(frame: Rect(origin: .zero, size: Size(width: 400, height: 400)))
//        blueView.backgroundColor = .blue
//        
//        self.backgroundColor = .white
//        
//        let redView = View(frame: Rect(origin: Point(x: 400, y: 0), size: Size(width: 400, height: 400)))
//        redView.backgroundColor = .red.opacity(0.3)
//        
//        self.addSubview(blueView)
//        self.addSubview(redView)
    }
    
    override func draw(in rect: Rect, with context: GUIRenderContext) {
//        context.setFillColor(.white)
//        context.fillRect(rect)
        
        context.setFillColor(.yellow)
        
        let transform = Transform3D(translation: [0, 0, 0], rotation: .identity, scale: [0.25, 0.25, 0.25])
        context.fillRect(transform)
        
//        context.setFillColor(.blue)
//        context.fillRect(Rect(x: 400, y: 0, width: 400, height: 400))
        
    }
}
