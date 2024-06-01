import AdaEngine

func makePlayer(for scene: Scene) throws {
    let player = Entity()

    player.components += Transform(scale: Vector3(0.2), position: [0, -0.85, 0])
    player.components += PlayerComponent()
    player.components += SpriteComponent(texture: characterAtlas[7, 1])

    scene.addEntity(player)
}
