//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

import AdaEngine

class EditorWindow: UIWindow {
    override func windowDidReady() {
        self.title = "Ada Editor"
        
        self.backgroundColor = .white

        let blueView = UIView(frame: Rect(origin: Point(x: 0, y: 0), size: Size(width: 50, height: 50)))
        blueView.backgroundColor = .blue

        let redView = UIView(frame: Rect(origin: Point(x: 100, y: 0), size: Size(width: 50, height: 50)))
//        redView.zIndex = 1
        redView.backgroundColor = .red

        self.addSubview(blueView)
        self.addSubview(redView)
    }
    
    override func draw(in rect: Rect, with context: GUIRenderContext) {
        print("Did render", rect)
        
        var count = Int(rect.width / 50)
        
        var x: Float = 0
        
        for i in 0..<count {
            context.drawRect(.init(x: x, y: 50, width: 50, height: 50), color: Color.random())
            x += 50
        }
        
    }
}
