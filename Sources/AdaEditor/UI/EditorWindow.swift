//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

import AdaEngine

struct NestedContent: View {

    @Binding var color: Color
    @State var innerColor: Color = .random()

    var body: some View {
        Self.printChanges()

        return HStack {
            innerColor
            Color.green
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                color = .random()
                innerColor = .random()
            }
        }
    }
}

struct ContentView: View {

    @State private var color = Color.brown
    @State private var isShown = false

    var body: some View {

        VStack {
            Text("Hello")

            Color.blue
                .frame(height: 140)

            Text("World")
        }
        .background(.red)
        .frame(width: 140)

//        ScrollView {
//            VStack {
//                ForEach(0..<30) { _ in
//                    Color.random()
//                        .cursorShape(.pointingHand)
//                }
//            }
//            .padding(16)
//        }
//        .background(
//            Color.gray
//        )
//        .onTap {
//            print("kek")
//        }

//        Self.printChanges()
//
//        return VStack {
//            NestedContent(color: $color)
//
//            Button {
//                print("Pressed")
//            } label: {
//                ImageView("Assets/dog.png", bundle: Bundle.editor)
//                    .resizable()
//                    .frame(width: 300, height: 120)
//            }
//        }
//        .padding(16)
//        .background(self.color)
//        .onAppear {
//            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
//                isShown.toggle()
//            }
//        }


    }

    var button: some View {
        Color.black
            .opacity(0.7)
            .frame(width: 40, height: 40)
    }
}

class EditorWindow: UIWindow {
    override func windowDidReady() {
        self.backgroundColor = .white

        let view = UIContainerView(rootView: ContentView())
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
