import AdaEngine

func makePlayer(for scene: Scene) throws {
    let player = Entity()

    player.components += PlayerComponent()

    scene.addEntity(player)
}

