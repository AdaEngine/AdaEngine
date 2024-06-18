//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

import AdaEngine

class EditorWindow: UIWindow {
    override func windowDidReady() {
        self.backgroundColor = .white
//
//        let blueView = UIView(frame: Rect(origin: Point(x: 0, y: 0), size: Size(width: 50, height: 50)))
//        blueView.backgroundColor = .blue
//
//        let redView = UIView(frame: Rect(origin: Point(x: 25, y: 25), size: Size(width: 50, height: 50)))
//        redView.zIndex = 1
//        redView.backgroundColor = .red
//
//        let redView1 = UIView(frame: Rect(origin: Point(x: 0, y: 0), size: Size(width: 10, height: 10)))
//        redView1.backgroundColor = .green
//
//        self.addSubview(blueView)
//        self.addSubview(redView)
//
//        redView.addSubview(redView1)

        let control = UIButton(frame: Rect(origin: Point(x: 20, y: 20), size: Size(width: 50, height: 50)))
        control.addAction(UIEventAction {
            print("Pressed")
        }, for: .touchDown)

        control.setBackgroundColor(.red.opacity(0.5), for: .selected)
        control.setBackgroundColor(.red, for: .normal)

        self.addSubview(control)

//        let label = UILabel(frame: Rect(origin: Point(x: 20, y: 20), size: Size(width: 20, height: 20)))
//        label.backgroundColor = .red
//        label.textColor = .black
//        label.text = "Hello World"
//        self.addSubview(label)
    }
    
    override func draw(in rect: Rect, with context: GUIRenderContext) {
        let size: Float = 100

        let count = Int(rect.width / size)

        var x: Float = rect.minX

        for i in 0 ..< count {
            context.drawRect(.init(x: x, y: 50, width: size, height: size), color: Color.random())
            x += size
        }
    }
}
