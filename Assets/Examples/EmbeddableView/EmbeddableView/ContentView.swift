////
////  ContentView.swift
////  EmbeddableView
////
////  Created by v.prusakov on 1/9/23.
////
//
//import SwiftUI
//import class AdaEngine.Scene
//import class AdaEngine.EventManager
//import protocol AdaEngine.Cancellable
//
//struct ContentView: View {
//    
//    @State private var scene: Scene?
//    @State private var counter: Int = 0
//    @State private var token: Cancellable?
//    
//    let builder = GameScene2D()
//    
//    var body: some View {
//        VStack {
//            if let scene = self.scene {
//                EngineView(scene: scene)
//                    .edgesIgnoringSafeArea(.all)
//            } else {
//                
//                Spacer()
//                Button("Start the game") {
//                    self.scene = try! builder.makeScene()
//                }
//                Spacer()
//            }
//            
//            if self.scene != nil {
//                Button("Restart") {
//                    self.scene = nil
//                    self.counter = 0
//                    
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                        self.scene = try! builder.makeScene()
//                    }
//                }
//            }
//            
//            Spacer()
//            
//            Text("User Score: \(counter)")
//                .font(.title)
//                .padding(.all, 16)
//        }
//        .onAppear {
//            self.token = EventManager.default.subscribe(for: UserScoreEvent.self) { event in
//                self.counter += 1
//            }
//        }
//        #if os(macOS)
//        .frame(width: 800, height: 600)
//        #endif
//    }
//}
