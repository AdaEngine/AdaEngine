//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

import AdaEngine

struct ContentView: Widget {

    @State private var color = Color.brown

    var body: some Widget {
        ScrollView {
            VStack {
                ForEach(0..<30) { _ in
                    Color.random()
                }
            }
            .padding(16)
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
}
