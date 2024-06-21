//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

import AdaEngine

struct ContentView: Widget {
    var body: some Widget {
        HStack(spacing: 8) {

            Color.red

            VStack {
                Color.green

                Color.blue
            }

//            VStack(spacing: 8) {
//                Color.yellow
//
//                Color.blue
//            }

//            VStack(spacing: 8) {
//                Color.red
//
//                Color.green
//            }
        }
    }
}

class EditorWindow: UIWindow {
    override func windowDidReady() {
        self.backgroundColor = .white

        let view = UIWidgetView(rootView: ContentView())
        view.autoresizingRules = [.flexibleWidth, .flexibleHeight]
        self.addSubview(view)

//        let blueView = UIView(frame: Rect(origin: Point(x: 0, y: 0), size: Size(width: 50, height: 50)))
//        blueView.backgroundColor = .blue
//
//        let redView = UIView(frame: Rect(origin: Point(x: 25, y: 25), size: Size(width: 50, height: 50)))
//        redView.backgroundColor = .red
//
//        let redView1 = UIView(frame: Rect(origin: Point(x: 0, y: 0), size: Size(width: 10, height: 10)))
//        redView1.backgroundColor = .green

//        self.addSubview(blueView)
//        self.addSubview(redView)
//
//        redView.addSubview(redView1)
//
//        let control = UIButton(frame: Rect(origin: Point(x: 20, y: 20), size: Size(width: 50, height: 50)))
//        control.addAction(UIEventAction {
//            print("Pressed")
//        }, for: .touchDown)
//
//        control.setBackgroundColor(.red.opacity(0.5), for: .selected)
//        control.setBackgroundColor(.red, for: .normal)
//
//        self.addSubview(control)

//        let greenView = UIView()
//        greenView.backgroundColor = .orange
//
//        let nestedStack = UIStackView(.vertical, children: [
//            redView,
//            greenView
//        ])
//
//        nestedStack.spacing = 8
//
//        let stack = UIStackView(.horizontal, children: [
//            blueView,
//            nestedStack
//        ])
//
//        stack.spacing = 8
//
//        stack.backgroundColor = .green.opacity(0.3)
//        stack.autoresizingRules = [.flexibleWidth, .flexibleHeight]
//
//        self.addSubview(stack)

        // FIXME: SceneView doesnt render when UI does
//        let scene = TilemapScene()
//        let sceneView = SceneView(scene: scene, frame: Rect(origin: Point(x: 60, y: 60), size: Size(width: 250, height: 250)))
//        sceneView.backgroundColor = .red
//        self.addSubview(sceneView)

//        let label = UILabel(frame: Rect(origin: Point(x: 20, y: 20), size: Size(width: 20, height: 20)))
//        label.backgroundColor = .red
//        label.textColor = .black
//        label.text = "Hello World"
//        self.addSubview(label)
    }
    
    override func draw(in rect: Rect, with context: GUIRenderContext) {
//        let size: Float = 100
//
//        let count = Int(rect.width / size)
//
//        var x: Float = rect.minX
//
//        for _ in 0 ..< count {
//            context.drawRect(.init(x: x, y: 50, width: size, height: size), color: Color.random())
//            x += size
//        }
    }
}
