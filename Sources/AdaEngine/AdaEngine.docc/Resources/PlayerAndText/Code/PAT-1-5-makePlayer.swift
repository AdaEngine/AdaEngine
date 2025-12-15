import AdaEngine

func makePlayer(in world: World, characterAtlas: TextureAtlas) {
    world.spawn {
        PlayerComponent()
        Transform(position: [0, -300, 0])
        Sprite(texture: characterAtlas[7, 1], size: Size(width: 24, height: 24))
    }
}
