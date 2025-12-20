//
//  ButtonExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 19.12.2025.
//

import AdaEngine

@main
struct ButtonExample: App {
    var body: some AppScene {
        WindowGroup {
            ContentView()
        }
        .windowMode(.windowed)
    }
}

struct ContentView: View {

    @State private var buttonText: String = "Click me"

    var body: some View {
        Button {
            buttonText = "Thanks!"
        } label: {
            Text(buttonText)
        }
        .padding(.all, 8)
        .background(.red)
    }
}
