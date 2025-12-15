import AdaEngine

struct PlayerAndTextPlugin: Plugin {
    let characterAtlas: TextureAtlas

    func setup(in app: borrowing AppWorlds) {
        self.makePlayer(in: app.main)
    }

    private func makePlayer(in world: World) {
        world.spawn {
            PlayerComponent()
            Transform(position: [0, -300, 0])
            Sprite(texture: characterAtlas[7, 1], size: Size(width: 24, height: 24))
        }
    }
}
