import AdaEngine

struct ContentView: View {
    @State private var timeOffset: Double = 0

    var body: some View {
        Text("Sine Wave")
            .textRendered(AnimatedSineWaveRenderer(timeOffset: timeOffset))
    }
}
