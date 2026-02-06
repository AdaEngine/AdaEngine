import AdaEngine

struct ContentView: View {
    @State private var buttonText: String = "Click me"

    var body: some View {
        VStack(spacing: 12) {
            Color.blue

            Text("UI Test Scene")
                .font(.system(size: 17))
                .background(.red)

            Button {
                let phrases = ["Thanks!", "Best click ever!", "You are awesome!"]
                buttonText = phrases.randomElement() ?? "Thanks!"
            } label: {
                Text(buttonText)
                    .foregroundColor(.white)
            }
            .padding(.all, 8)
            .background(.blue)

            Color.green
        }
        .padding(.all, 12)
    }
}
