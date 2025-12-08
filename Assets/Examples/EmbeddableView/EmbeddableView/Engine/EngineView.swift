////
////  EngineView.swift
////  EmbeddableView
////
////  Created by v.prusakov on 1/9/23.
////
//
//import SwiftUI
//import AdaEngineEmbeddable
//import AdaEngine
//
//struct EngineView {
//    let scene: AdaEngine.Scene
//}
//
//#if os(iOS)
//extension EngineView: UIViewRepresentable {
//    
//    func makeUIView(context: Context) -> AEView {
//        AEView(scene: self.scene, frame: .zero)
//    }
//    
//    func updateUIView(_ uiView: AEView, context: Context) { }
//}
//#endif
//
//#if os(macOS)
//extension EngineView: NSViewRepresentable {
//    func makeNSView(context: Context) -> some NSView {
//        AEView(scene: self.scene, frame: .zero)
//    }
//    
//    func updateNSView(_ nsView: NSViewType, context: Context) { }
//}
//#endif
