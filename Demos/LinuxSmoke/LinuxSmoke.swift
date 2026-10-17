import AdaEngine
@_spi(Internal) import AdaPlatform
import Foundation

@main
struct LinuxSmoke: App {
    var body: some AppScene {
        WindowGroup {
            LinuxSmokeView()
        }
        .window(
            with: UIWindow.Configuration(
                title: "AdaEngine Linux",
                frame: Rect(x: 80, y: 80, width: 800, height: 600),
                minimumSize: Size(width: 480, height: 360)
            )
        )
    }
}

private struct LinuxSmokeView: View {
    @State private var clicks = 0
    @State private var text = "Hello, Linux!"

    var body: some View {
        VStack(spacing: 24) {
            Text("AdaEngine on Linux")
                .font(.system(size: 36))
            Text("Resize the window, type a message and press the button.")
            TextField("Message", text: $text)
                .frame(width: 360, height: 44)
            Button("Clicks: \(clicks)") {
                clicks += 1
                smokeLog("LINUX_SMOKE_CLICK \(clicks) text=\(text)")
            }
            Text(text)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .task {
            smokeLog("LINUX_SMOKE_READY backend=\(RenderEngine.shared.type)")
        }
    }
}

private func smokeLog(_ message: String) {
    FileHandle.standardOutput.write(Data((message + "\n").utf8))
}
