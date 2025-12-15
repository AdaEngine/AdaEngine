import AdaEngine

struct FirstScene: Plugin {
    func setup(in app: AppWorlds) {
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(45/255, 171/255, 255/255, 1)
        app.addEntity(cameraEntity)

        let spriteSheetImage = try! AssetsManager.loadSync("@res://characters_packed.png") as Image
        let spriteSheet = TextureAtlas(from: spriteSheetImage, size: [20, 23], margin: [4, 1])

        let playerEntity = Entity(name: "Player")
        playerEntity.components += Sprite(texture: spriteSheet[7, 1])
        playerEntity.components += Transform(scale: Vector3(0.19))
        app.addEntity(playerEntity)
    }
}
