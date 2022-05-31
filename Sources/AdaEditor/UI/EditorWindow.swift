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
}
