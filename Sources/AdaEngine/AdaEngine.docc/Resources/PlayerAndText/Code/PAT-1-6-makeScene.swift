import AdaEngine

@MainActor
func makeScene() async throws -> Scene {
    let scene = Scene()
    try self.makePlayer(for: scene)
}
