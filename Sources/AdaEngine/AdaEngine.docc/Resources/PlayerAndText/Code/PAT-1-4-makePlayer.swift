import AdaEngine

func makePlayer(in world: World) {
    world.spawn {
        PlayerComponent()
        Transform(position: [0, -300, 0])
    }
}
