import AdaEngine

func makeScore(in app: borrowing AppWorlds) throws {
    var container = TextAttributeContainer()
    container.foregroundColor = .white
    let attributedText = AttributedText("Score: 0", attributes: container)

    app.main.spawn("Score") {
        TextComponent(text: attributedText)
        Transform(position: [0, -500, 0])
    }

    app.insertResource(GameState())
}
