import AdaEngine

func makeScore(for scene: Scene) throws {
    let score = Entity(name: "Score")

    var container = TextAttributeContainer()
    container.foregroundColor = .white
    let attributedText = AttributedText("Score: 0", attributes: container)

    score.components += Text2DComponent(text: attributedText)
    score.components += GameState()
    score.components += Transform(scale: Vector3(0.1), position: [-0.2, -0.9, 0])
    
    scene.addEntity(score)
}
