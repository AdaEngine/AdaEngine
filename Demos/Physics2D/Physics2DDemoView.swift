import AdaEngine
import Observation

struct Physics2DDemoApp: App {
    var body: some AppScene {
        WindowGroup { Physics2DDemoView() }
            .window(with: UIWindow.Configuration(title: "AdaEngine · Box2D playground", frame: Rect(x: 100, y: 100, width: 1000, height: 700)))
    }
}

private struct Physics2DDemoView: View {
    @State private var scene = PhysicsDemoScene.raycast
    @State private var raycast = PhysicsDemoSession(scene: .raycast)
    @State private var events = PhysicsDemoSession(scene: .events)
    @State private var queries = PhysicsDemoSession(scene: .queries)

    var body: some View {
        VStack(spacing: 12) {
            Text("Box2D playground").font(.system(size: 26))
            HStack(spacing: 20) {
                Button("Raycasts") { scene = .raycast }.accessibilityIdentifier("physics-demo.raycasts")
                Button("Collisions & sensors") { scene = .events }.accessibilityIdentifier("physics-demo.events")
                Button("Geometry & queries") { scene = .queries }.accessibilityIdentifier("physics-demo.queries")
            }
            if scene == .raycast {
                HStack(spacing: 18) {
                    Button(raycast.allHits ? "All hits" : "Nearest hit") { raycast.allHits.toggle() }.accessibilityIdentifier("physics-demo.mode")
                    Button(raycast.blueOnly ? "Blue targets only" : "All layers") { raycast.blueOnly.toggle() }.accessibilityIdentifier("physics-demo.mask")
                    Button(raycast.scan ? "Hold horizontal ray" : "Animate ray") { raycast.scan.toggle() }.accessibilityIdentifier("physics-demo.scan")
                }
                Text("White markers show hits in distance order. Toggle the orange layer or nearest hit.")
                Text(raycast.rayStatus)
                SceneView(useSceneCameras: true, make: { configurePhysicsDemo(&$0, session: raycast) }, updateContent: { _, _ in })
                    .frameCaptureLabel("Physics2D Raycasts")
                    .id(PhysicsDemoScene.raycast)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scene == .queries {
                PhysicsQueriesDemoPane(session: queries)
            } else {
                Button("Drop box again") { events.resetRequested = true }.accessibilityIdentifier("physics-demo.drop")
                Text("Blue box crosses the green sensor freely. Orange box bounces on the floor.")
                Text("Contacts: \(events.contactBegins) begin / \(events.contactEnds) end · Impacts: \(events.impacts)")
                Text("Sensor: \(events.sensorBegins) enter / \(events.sensorEnds) exit · \(events.sensorOccupied ? "occupied" : "empty")")
                SceneView(useSceneCameras: true, make: { configurePhysicsDemo(&$0, session: events) }, updateContent: { _, _ in })
                    .frameCaptureLabel("Physics2D Events")
                    .id(PhysicsDemoScene.events)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(18)
        .background(Color(0.035, 0.055, 0.10, 1))
        .foregroundColor(.white)
    }
}
