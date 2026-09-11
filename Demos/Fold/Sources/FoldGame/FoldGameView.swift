import AdaEngine

/// The game's entry point, usable in its app and the editor's ordinary Swift preview.
@Previewable(title: "Fold · Shadow platformer")
public struct FoldGameView: View {
    @State private var pose = FoldPose()
    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("FOLD / Foldable Preview").foregroundColor(.white)
                Spacer()
                ForEach([180, 135, 90], id: \.self) { angle in
                    Button(String(angle) + "°") { pose.angle = Float(angle) }
                        .foregroundColor(.white)
                        .accessibilityIdentifier("ShadowFold.Angle." + String(angle))
                }
            }.padding(12).background(Color.fromHex(0x19283A))
            ShadowFoldView(pose: $pose, make: { app in
                FoldProject.configure(&app)
            })
        }
    }
}
