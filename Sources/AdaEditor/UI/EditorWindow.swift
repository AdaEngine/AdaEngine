//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

import AdaEngine

class EditorWindow: Window {
    override func windowDidReady() {
        self.title = "Ada Editor"
        
        self.canDraw = true
        
        self.backgroundColor = .red
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
        super.draw(in: rect, with: context)
    }
}
