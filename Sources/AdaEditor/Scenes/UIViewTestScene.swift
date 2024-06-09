//
//  UIViewTestScene.swift
//  
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

import AdaEngine

struct ContentWidget: Widget {
    
    @WidgetContext(\.font) private var font
    
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
