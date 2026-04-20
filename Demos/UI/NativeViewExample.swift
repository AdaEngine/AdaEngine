//
//  NativeViewExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.04.2026.
//

import AdaEngine

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(MapKit)
import MapKit
#endif

@main
struct NativeViewExample: AdaEngine.App {
    var body: some AppScene {
        WindowGroup {
            NativeViewDemo()
        }
        .windowMode(.windowed)
    }
}

struct NativeViewDemo: AdaEngine.View {
    
    @AdaEngine.State private var renderingMode: NativeRenderingMode = .offscreen
    @AdaEngine.State private var showMap = true
    
    var body: some AdaEngine.View {
        AdaEngine.ZStack {
            AdaEngine.Color.fromHex(0xEDEFF3)
            
            AdaEngine.VStack(spacing: 20) {
                AdaEngine.Text("Native View Integration")
                    .fontSize(32)
                
                AdaEngine.HStack(spacing: 10) {
                    AdaEngine.Button {
                        renderingMode = .offscreen
                    } label: {
                        AdaEngine.Text("Offscreen Mode")
                            .padding(10)
                            .background(renderingMode == .offscreen ? AdaEngine.Color.blue : AdaEngine.Color.gray)
                            .foregroundColor(.white)
                    }
                    
                    AdaEngine.Button {
                        renderingMode = .overlay
                    } label: {
                        AdaEngine.Text("Overlay Mode")
                            .padding(10)
                            .background(renderingMode == .overlay ? AdaEngine.Color.blue : AdaEngine.Color.gray)
                            .foregroundColor(.white)
                    }
                    
                    AdaEngine.Button {
                        showMap.toggle()
                    } label: {
                        AdaEngine.Text(showMap ? "Hide Map" : "Show Map")
                            .padding(10)
                            .background(AdaEngine.Color.green)
                            .foregroundColor(.white)
                    }
                }
                
                AdaEngine.ScrollView {
                    AdaEngine.VStack(spacing: 30) {
                        AdaEngine.Text("The section below is a native SwiftUI view:")
                            .fontSize(14)
                        
                        #if canImport(SwiftUI)
                        SwiftUIViewRepresentable {
                            SwiftUI.VStack {
                                SwiftUI.Text("I am SwiftUI Content")
                                    .font(.headline)
                                
                                SwiftUI.HStack {
                                    SwiftUI.Circle().fill(SwiftUI.Color.red).frame(width: 20, height: 20)
                                    SwiftUI.Circle().fill(SwiftUI.Color.green).frame(width: 20, height: 20)
                                    SwiftUI.Circle().fill(SwiftUI.Color.blue).frame(width: 20, height: 20)
                                }
                                
                                SwiftUI.Button("Native SwiftUI Button") {
                                    print("SwiftUI Button Tapped!")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .background(SwiftUI.Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        }
                        .frame(width: 300, height: 150)
                        .nativeRenderingMode(renderingMode)
                        #endif
                        
                        if showMap {
                            AdaEngine.Text("The section below is a native MapKit view:")
                                .fontSize(14)
                            
                            NativeMapView()
                                .frame(width: 500, height: 300)
                                .nativeRenderingMode(renderingMode)
                        }
                        
                        AdaEngine.Text("End of ScrollView Content")
                            .fontSize(12)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
                .frame(height: 500)
                .border(AdaEngine.Color.black, lineWidth: 1)
            }
            .padding(40)
        }
    }
}

#if canImport(MapKit)
#if os(macOS)
struct NativeMapView: AppKitViewRepresentable {
    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.wantsLayer = true
        return map
    }
    
    func updateNSView(_ nsView: MKMapView, context: Context) {
        // Update logic
    }
}
#elseif os(iOS) || os(tvOS) || os(visionOS)
struct NativeMapView: UIKitViewRepresentable {
    func makeUIView(context: Context) -> MKMapView {
        return MKMapView()
    }
    
    func updateUIView(_ uiView: MKMapView, in context: Context) {
        // Update logic
    }
}
#endif
#else
// Fallback if MapKit is not available
struct NativeMapView: AdaEngine.View {
    var body: some AdaEngine.View {
        AdaEngine.Text("MapKit not available on this platform")
            .frame(width: 500, height: 300)
            .background(.gray)
    }
}
#endif
