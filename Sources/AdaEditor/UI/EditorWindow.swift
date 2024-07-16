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
//        .onAppear {
//            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
//                viewModel.color = .random()
//            }
//        }
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

struct ContentView: View {

    @State private var offset: Double = 0

    var body: some View {
//
//        VStack {
//            NestedContent()
//            Color.red
//        }
//        .onPreferenceChange(SomeKey.self) { string in
//            print(string)
//        }

        Text("H e l l o, W o r l d")
//            .textRendered(AnimatedSineWaveOffsetRender(timeOffset: offset))
//            .onAppear {
//                print("On Appear")
//                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
//                    if offset > 1_000_000_000_000 {
//                      offset = 0 // Reset the time offset
//                    }
//                    offset += 10
//                }
//            }
            .background(.red)
            .frame(width: 204, height: 24)

        //        VStack {
        //            Text("Hello")
        //                .frame(width: 100, height: 23)
        //                .background(Color.mint)
        //
        //            viewModel.color
        //                .frame(height: 140)
        //
        //            Text("World")
        //                .frame(width: 100, height: 23)
        //                .background(Color.green)
        //        }
        //        .font(.system(size: 17))
        //        .background(.red)
        //        .frame(width: 140)
        //        .environment(viewModel)
        //        .lineLimit(2)
    }
}
//
//ScrollView {
//    VStack {
//        ForEach(0..<30) { _ in
//            Color.random()
//                .cursorShape(.pointingHand)
//        }
//    }
//    .padding(16)
//}
//.background(
//    Color.gray
//)
//.onTap {
//    print("kek")
//}
//
//Self.printChanges()
//
//return VStack {
//    NestedContent(color: $color)
//
//    Button {
//        print("Pressed")
//    } label: {
//        ImageView("Assets/dog.png", bundle: Bundle.editor)
//            .resizable()
//            .frame(width: 300, height: 120)
//    }
//}
//.padding(16)
//.background(self.color)
//.onAppear {
//    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
//        isShown.toggle()
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

        //        let label = UILabel(frame: Rect(origin: Point(x: 20, y: 20), size: Size(width: 20, height: 20)))
        //        label.backgroundColor = .red
        //        label.textColor = .black
        //        label.text = "Hello World"
        //        self.addSubview(label)
    }
}
