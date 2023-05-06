import AdaEngine

@main
struct FirstGameApp: App {
    
    let game = FirstScene()
    
    var body: some AppScene {
        GameAppScene {
            self.game.makeScene() // Returns game scene to the Engine
        }
    }
}
