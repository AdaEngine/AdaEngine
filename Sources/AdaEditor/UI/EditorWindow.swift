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
        
        let blueView = View(frame: Rect(origin: .zero, size: Size(width: 30, height: 30)))
        blueView.backgroundColor = .blue
        
        self.addSubview(blueView)
    }
    
    override func draw(in rect: Rect, with context: GUIRenderContext) {
        context.setFillColor(.green)
        context.fillRect(rect)
        
        context.setZIndex(1)
        context.setFillColor(Color.blue.opacity(0.1))
        context.fillRect(
            Rect(
                origin: .zero,
                size: Size(width: rect.size.width / 2, height: rect.size.height / 2))
        )
    }
}
