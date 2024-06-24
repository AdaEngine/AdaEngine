//
//  UIViewTestScene.swift
//  
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaEngine

struct ContentWidget: Widget {
    
    @WidgetEnvironment(\.font) private var font
    
    @State private var int = 0
    @State private var double = 0.0
    
    var body: some Widget {
        HStack {
            Text("Hello World")
            
            CustomWidget()
            
            Text("Hello World")
                
        }
        
        Text("Hello World")
    }
}

struct CustomWidget: Widget {
    
    @State private var string = ""
    
    var body: some Widget {
        Text("Hello World")
        
        Text("Hello World")
    }
}

class UIViewTestScene: Scene {
    
    override func sceneDidMove(to view: SceneView) {
        let view1 = UIView(frame: Rect(x: 0, y: 0, width: 50, height: 50))
        view1.backgroundColor = .red
        let view2 = UIView(frame: Rect(x: 70, y: 0, width: 50, height: 50))
        view1.backgroundColor = .green
        view.addSubview(view1)
        
        view.addSubview(view2)
    }
    
}
