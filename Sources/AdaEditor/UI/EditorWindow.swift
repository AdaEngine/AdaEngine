//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

import AdaEngine
import Observation

@Observable
class ViewModel {
    var color = Color.blue
    var isShown = false
}

struct NestedContent: View {

    @State var innerColor: Color = .red

    var body: some View {
        return HStack {
            innerColor
                .preference(key: SomeKey.self, value: "kek")
            Color.green
                .preference(key: SomeKey.self, value: "kek")
        }
    }
}

extension Text.Layout {
    var runs: some RandomAccessCollection<TextRun> {
        flatMap { line in
            line
        }
    }

    var flattenedRuns: some RandomAccessCollection<Glyph> {
        runs.flatMap { $0 }
    }
}

struct AnimatedSineWaveOffsetRender: TextRenderer {
    
    let timeOffset: Double // Time offset

    init(timeOffset: Double) {
        self.timeOffset = timeOffset
    }

    func draw(layout: Text.Layout, in context: inout UIGraphicsContext) {
        let count = layout.flattenedRuns.count // Count all RunSlices in the text layout
        let width = layout.first?.typographicBounds.rect.width ?? 0 // Get the width of the text line
        let height = layout.first?.typographicBounds.rect.height ?? 0 // Get the height of the text line
        // Iterate through each RunSlice and its index
        for (index, glyph) in layout.flattenedRuns.enumerated() {
            // Calculate the sine wave offset for the current character
            let offset = animatedSineWaveOffset(
                forCharacterAt: index,
                amplitude: Double(height) / 2, // Set amplitude to half the line height
                wavelength: Double(width),
                phaseOffset: timeOffset,
                totalCharacters: count
            )
            // Create a copy of the context and translate it
            var copy = context
            copy.translateBy(x: 0, y: Float(offset))
            // Draw the current RunSlice in the modified context
            copy.draw(glyph)
        }

        func animatedSineWaveOffset(forCharacterAt index: Int, amplitude: Double, wavelength: Double, phaseOffset: Double, totalCharacters: Int) -> Double {
            let x = Double(index)
            let position = (x / Double(totalCharacters)) * wavelength
            let radians = ((position + phaseOffset) / wavelength) * 2 * .pi
            return Math.sin(radians) * amplitude
        }
    }
}

struct SomeKey: PreferenceKey {
    static let defaultValue: String = ""
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
    }
}

struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(.white)
            .frame(width: 100, height: 100)
            .font(Font.system(size: 18, weight: .bold))
            .background(self.background(in: configuration))
            .border(.black)
    }

    func background(in configuration: Configuration) -> Color {
        if configuration.state.isHighlighted {
            return Color(red: 244 / 255, green: 234 / 255, blue: 234 / 255)
        } else if configuration.state.isSelected {
            return Color.green
        } else {
            return Color(red: 18 / 255, green: 38 / 255, blue: 58 / 255)
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 32) {
                ZStack {
                    Color.green
                        .frame(width: 100, height: 100)

                    ImageView("Assets/dog.png", bundle: .editor)
                        .resizable()
                        .frame(width: 50, height: 50)
                }

                ZStack {
                    Color.green
                        .frame(width: 100, height: 100)

                    ImageView("Assets/dog.png", bundle: .editor)
                        .resizable()
                        .frame(width: 50, height: 50)
                }
                .drawingGroup()
            }

            Text("Some sort of text")
                .border(.red)
        }
//        Text("Kek")
//            .border(.red)
//            .foregroundColor(.white)
//            .frame(width: 100, height: 100)
//            .font(Font.system(size: 18, weight: .bold))
//            .background(Color(red: 18 / 255, green: 38 / 255, blue: 58 / 255))
//            .border(.black)
//        Button(action: {
//            
//        }, label: {
//            Text("Kek")
//              .border(.red)
//        })
//        .buttonStyle(CustomButtonStyle())

//        .frame(width: 400, height: 400)
//        .border(.red)
    }
}

//
//struct ContentView: View {
//
//    let topID = "1"
//    let bottomID = "2"
//    @State private var offset: Double = 0
//
//    var body: some View {
//        ScrollViewReader { proxy in
//            ScrollView {
//                Button(action: {
//                    proxy.scrollTo(bottomID)
//                }, label: {
//                    Text("Scroll to Bottom")
//                        .padding(16)
//                        .border(.blue)
//                        .id(topID)
//                })
//                .id(topID)
//
//                VStack(spacing: 0) {
//                    ForEach(0..<100) { i in
//                        color(fraction: Float(i) / 100)
//                            .frame(height: 32)
//                    }
//                }
//
//                Button {
//                    proxy.scrollTo(topID)
//                } label: {
//                    Text("Top")
//                }
//                .id(bottomID)
//                .frame(height: 60)
//            }
//        }
//        .buttonStyle(CustomButtonStyle())
////        HStack {
////            ScrollView {
////                VStack {
////                    ForEach(0..<30) { index in
////                        Text("Row by index: \(index)")
////                            .background(.random())
////                            .cursorShape(.pointingHand)
////                    }
////                }
////                .padding(16)
////            }
////            .frame(width: 200)
////            .background(.red)
////
////            Spacer()
////
////            ScrollView {
////                VStack {
////                    ForEach(0..<30) { index in
////                        Text("Row by index: \(index)")
////                            .background(.random())
////                            .cursorShape(.pointingHand)
////                    }
////                }
////                .padding(16)
////            }
////            .frame(width: 200)
////            .background(.gray)
////        }
//    }
//
//    func color(fraction: Float) -> Color {
//        Color(red: fraction, green: 1 - fraction, blue: 0.5)
//    }
//}

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
    }
}
