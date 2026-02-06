import AdaEngine

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Color.blue

            Text("UI Test Scene")
                .font(.system(size: 17))
                .background(.red)

            Color.green
        }
        .padding(.all, 12)
    }
}
