//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

import AdaEngine

struct ContentView: Widget {

    @State private var color: Color = Color.brown

    var body: some Widget {
        HStack(spacing: 8) {
            Color.red

//            VStack {
//                Color.blue
//                Color.brown
//                Color.blue
//            }

            Color.green
//            Canvas { context, size in
//                context.drawRect(Rect(origin: .zero, size: size), color: .yellow)
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
