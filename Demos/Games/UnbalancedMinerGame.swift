//
//  UnbalancedMinerGame.swift
//  AdaEngine
//
//  First playable flow: menu -> intro -> mining module.
//

import AdaEngine

@main
struct UnbalancedMinerApp: App {
    var body: some AppScene {
        WindowGroup {
            UnbalancedMinerRootView()
        }
        .windowMode(.windowed)
        .windowTitle("Unbalanced Miner")
    }
}

enum MinerScreen: Equatable {
    case menu
    case intro
    case gameplay
}

struct MinerFlowState: Equatable {
    private(set) var screen: MinerScreen = .menu

    mutating func start() {
        guard screen == .menu else { return }
        screen = .intro
    }

    mutating func finishIntro() {
        guard screen == .intro else { return }
        screen = .gameplay
    }

    mutating func returnToMenu() {
        screen = .menu
    }
}

private struct UnbalancedMinerRootView: View {
    @State private var flow = MinerFlowState()

    var body: some View {
        ZStack {
            MinerPalette.space

            switch flow.screen {
            case .menu:
                MainMenuView {
                    flow.start()
                }
            case .intro:
                IntroView {
                    flow.finishIntro()
                }
            case .gameplay:
                GameplayView {
                    flow.returnToMenu()
                }
            }
        }
        .frame(minWidth: 960, maxWidth: .infinity, minHeight: 600, maxHeight: .infinity)
    }
}

private struct MainMenuView: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            StarfieldView()

            VStack(alignment: .center, spacing: 18) {
                Text("UNBALANCED")
                    .fontSize(54)
                    .foregroundColor(MinerPalette.warning)

                Text("MINER")
                    .fontSize(28)
                    .foregroundColor(.white)

                Text("Один инженер. Один неисправный модуль. Один путь домой.")
                    .fontSize(15)
                    .foregroundColor(MinerPalette.textSecondary)
                    .padding(EdgeInsets(top: 2, leading: 0, bottom: 24, trailing: 0))

                Button(action: onStart) {
                    Text("НАЧАТЬ СМЕНУ")
                        .fontSize(16)
                        .foregroundColor(MinerPalette.space)
                        .padding(EdgeInsets(top: 13, leading: 34, bottom: 13, trailing: 34))
                        .background(MinerPalette.warning)
                        .border(MinerPalette.warningLight, lineWidth: 2)
                }
                .accessibilityIdentifier("start game")

                Text("WASD — движение  •  E — взаимодействие")
                    .fontSize(12)
                    .foregroundColor(MinerPalette.textMuted)
                    .padding(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
            }
            .padding(40)
            .background(MinerPalette.panel.opacity(0.94))
            .border(MinerPalette.border, lineWidth: 2)
        }
    }
}

private struct StarfieldView: View {
    var body: some View {
        ZStack {
            MinerPalette.space

            VStack(spacing: 64) {
                Text("·       ✦              ·          ·              ✧")
                Text("       ·          ·          ✦             ·")
                Text("  ✧              ·                 ·     ✦")
                Text("          ·             ✧                    ·")
            }
            .fontSize(18)
            .foregroundColor(MinerPalette.star)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }
}

private struct IntroView: View {
    let onComplete: () -> Void

    var body: some View {
        ZStack(anchor: .bottom) {
            IntroScene(onComplete: onComplete)

            VStack(alignment: .leading, spacing: 10) {
                Text("БОРТОВОЙ ЖУРНАЛ // 01")
                    .fontSize(12)
                    .foregroundColor(MinerPalette.warning)

                Text("Варп-двигатель уничтожен. Связи нет.")
                    .fontSize(24)
                    .foregroundColor(.white)

                Text("Шахтёрский модуль ещё отвечает. Если добыть достаточно феррита — у нас появится шанс вернуться домой.")
                    .fontSize(14)
                    .foregroundColor(MinerPalette.textSecondary)

                HStack {
                    Text("ПЕРВАЯ ЦЕЛЬ: запустить модуль и начать добычу")
                        .fontSize(12)
                        .foregroundColor(MinerPalette.success)

                    Spacer()

                    Button(action: onComplete) {
                        Text("ПРОПУСТИТЬ  ›")
                            .fontSize(12)
                            .foregroundColor(.white)
                            .padding(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                            .background(MinerPalette.panelLight)
                            .border(MinerPalette.border)
                    }
                    .accessibilityIdentifier("skip intro")
                }
            }
            .padding(22)
            .background(MinerPalette.panel.opacity(0.96))
            .border(MinerPalette.border, lineWidth: 1)
            .padding(32)
        }
    }
}

private struct IntroScene: View {
    let onComplete: () -> Void

    var body: some View {
        SceneView(
            make: { app in
                MinerWorld.configure(&app)
                IntroWorld.setup(app.main)
            },
            updateContent: { world, deltaTime in
                IntroWorld.update(world, deltaTime: deltaTime, onComplete: onComplete)
            }
        )
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }
}

private enum IntroWorld {
    static func setup(_ world: World) {
        world.insertResource(IntroState())
        MinerWorld.spawnCamera(in: world, background: MinerPalette.space)

        world.spawn("BrokenShip") {
            Sprite(
                texture: Texture2D.whiteTexture,
                tintColor: MinerPalette.ship,
                size: Size(width: 420, height: 130)
            )
            Transform(position: Vector3(-80, 60, 0))
        }

        world.spawn("ShipCore") {
            Sprite(
                texture: Texture2D.whiteTexture,
                tintColor: MinerPalette.danger,
                size: Size(width: 74, height: 74)
            )
            Transform(position: Vector3(20, 60, 2))
        }

        world.spawn("MiningModule") {
            Sprite(
                texture: Texture2D.whiteTexture,
                tintColor: MinerPalette.warning,
                size: Size(width: 110, height: 70)
            )
            Transform(position: Vector3(310, -110, 1))
        }
    }

    static func update(_ world: World, deltaTime: TimeInterval, onComplete: () -> Void) {
        guard var state = world.getResource(IntroState.self) else { return }
        state.elapsed += deltaTime

        for entity in world.getEntities() {
            guard entity.name == "MiningModule", var transform = entity.components[Transform.self] else { continue }
            transform.position.x -= Float(deltaTime) * 28
            transform.position.y += Float(deltaTime) * 10
            entity.components += transform
        }

        if state.elapsed >= 5, !state.didComplete {
            state.didComplete = true
            onComplete()
        }
        world.insertResource(state)
    }
}

private struct IntroState: Resource {
    var elapsed: TimeInterval = 0
    var didComplete = false
}

private struct GameplayView: View {
    let onExit: () -> Void

    var body: some View {
        ZStack(anchor: .topLeading) {
            SceneView(
                make: { app in
                    MinerWorld.configure(&app)
                    GameplayWorld.setup(app.main)
                },
                updateContent: { world, deltaTime in
                    GameplayWorld.update(world, deltaTime: deltaTime)
                }
            )
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)

            GameplayHUD(onExit: onExit)
        }
    }
}

private struct GameplayHUD: View {
    let onExit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("СМЕНА 01 // БЕЗОПАСНАЯ РАВНИНА")
                    .fontSize(11)
                    .foregroundColor(MinerPalette.warning)

                Text("07:00")
                    .fontSize(30)
                    .foregroundColor(.white)

                Text("ЗАДАЧИ")
                    .fontSize(11)
                    .foregroundColor(MinerPalette.textMuted)

                Text("□ Добраться до энергоблока")
                    .fontSize(13)
                    .foregroundColor(.white)

                Text("□ Запустить генератор")
                    .fontSize(13)
                    .foregroundColor(MinerPalette.textSecondary)

                Text("□ Запустить бур")
                    .fontSize(13)
                    .foregroundColor(MinerPalette.textSecondary)
            }
            .padding(16)
            .background(MinerPalette.panel.opacity(0.94))
            .border(MinerPalette.border)

            Spacer()
                .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 8) {
                Text("WASD — ДВИЖЕНИЕ")
                    .fontSize(11)
                    .foregroundColor(MinerPalette.textSecondary)

                Text("МОСТИК")
                    .fontSize(12)
                    .foregroundColor(MinerPalette.success)

                Button(action: onExit) {
                    Text("В МЕНЮ")
                        .fontSize(11)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(MinerPalette.panelLight)
                        .border(MinerPalette.border)
                }
            }
            .padding(16)
            .background(MinerPalette.panel.opacity(0.90))
            .border(MinerPalette.border)
        }
        .padding(20)
    }
}

private enum MinerWorld {
    @MainActor
    static func configure(_ app: inout AppWorlds) {
        app.addPlugin(TransformPlugin())
        app.addPlugin(InputPlugin())
        app.addPlugin(RenderWorldPlugin())
        app.addPlugin(EventsPlugin())
        app.addPlugin(CameraPlugin())
        app.addPlugin(AssetsPlugin(filePath: #filePath))
        app.addPlugin(VisibilityPlugin())
        app.addPlugin(SpritePlugin())
        app.addPlugin(Mesh2DPlugin())
        app.addPlugin(Core2DPlugin())
        app.addPlugin(UpscalePlugin())
    }

    static func spawnCamera(in world: World, background: Color) {
        var camera = Camera()
        camera.backgroundColor = background
        camera.clearFlags = .solid
        world.spawn(bundle: Camera2D(camera: camera))
    }
}

private enum GameplayWorld {
    static func setup(_ world: World) {
        world.insertResource(GameplayState())
        MinerWorld.spawnCamera(in: world, background: MinerPalette.space)

        spawnRoom(in: world, name: "Bridge", position: Vector3(-310, 120, -10), size: Size(width: 310, height: 220), color: MinerPalette.bridge)
        spawnRoom(in: world, name: "Cargo", position: Vector3(0, 120, -10), size: Size(width: 250, height: 220), color: MinerPalette.room)
        spawnRoom(in: world, name: "Drill", position: Vector3(300, 120, -10), size: Size(width: 270, height: 220), color: MinerPalette.drill)
        spawnRoom(in: world, name: "Power", position: Vector3(0, -150, -10), size: Size(width: 250, height: 230), color: MinerPalette.power)

        spawnCorridor(in: world, position: Vector3(-155, 120, -8), size: Size(width: 60, height: 72))
        spawnCorridor(in: world, position: Vector3(150, 120, -8), size: Size(width: 60, height: 72))
        spawnCorridor(in: world, position: Vector3(0, -15, -8), size: Size(width: 72, height: 60))

        world.spawn("Player") {
            MinerPlayer()
            Sprite(texture: Texture2D.whiteTexture, tintColor: MinerPalette.player, size: Size(width: 34, height: 34))
            Transform(position: Vector3(-310, 120, 5))
        }

        world.spawn("Generator") {
            Sprite(texture: Texture2D.whiteTexture, tintColor: MinerPalette.warning, size: Size(width: 70, height: 54))
            Transform(position: Vector3(0, -150, 1))
        }

        world.spawn("DrillConsole") {
            Sprite(texture: Texture2D.whiteTexture, tintColor: MinerPalette.success, size: Size(width: 76, height: 48))
            Transform(position: Vector3(300, 120, 1))
        }
    }

    static func update(_ world: World, deltaTime: TimeInterval) {
        guard var state = world.getResource(GameplayState.self) else { return }
        state.elapsed += deltaTime

        guard let input = world.getResource(Input.self) else {
            world.insertResource(state)
            return
        }

        var direction = Vector2.zero
        if input.isKeyPressed(.a) || input.isKeyPressed(.arrowLeft) { direction.x -= 1 }
        if input.isKeyPressed(.d) || input.isKeyPressed(.arrowRight) { direction.x += 1 }
        if input.isKeyPressed(.w) || input.isKeyPressed(.arrowUp) { direction.y += 1 }
        if input.isKeyPressed(.s) || input.isKeyPressed(.arrowDown) { direction.y -= 1 }

        if direction != .zero {
            state.playerPosition += direction.normalized * 230 * deltaTime
            state.playerPosition.x = min(max(state.playerPosition.x, -445), 435)
            state.playerPosition.y = min(max(state.playerPosition.y, -265), 230)
        }

        for entity in world.getEntities() {
            guard entity.components[MinerPlayer.self] != nil, var transform = entity.components[Transform.self] else { continue }
            transform.position.x = state.playerPosition.x
            transform.position.y = state.playerPosition.y
            entity.components += transform
        }
        world.insertResource(state)
    }

    private static func spawnRoom(in world: World, name: String, position: Vector3, size: Size, color: Color) {
        world.spawn(name) {
            Sprite(texture: Texture2D.whiteTexture, tintColor: color, size: size)
            Transform(position: position)
        }
    }

    private static func spawnCorridor(in world: World, position: Vector3, size: Size) {
        world.spawn("Corridor") {
            Sprite(texture: Texture2D.whiteTexture, tintColor: MinerPalette.corridor, size: size)
            Transform(position: position)
        }
    }
}

private struct GameplayState: Resource {
    var elapsed: TimeInterval = 0
    var playerPosition = Vector2(-310, 120)
}

@Component
private struct MinerPlayer {}

private enum MinerPalette {
    static let space = Color.fromHex(0x070B12)
    static let panel = Color.fromHex(0x101923)
    static let panelLight = Color.fromHex(0x1D2A36)
    static let border = Color.fromHex(0x405364)
    static let textSecondary = Color.fromHex(0xA7B5C2)
    static let textMuted = Color.fromHex(0x6F8190)
    static let warning = Color.fromHex(0xF0A83A)
    static let warningLight = Color.fromHex(0xFFD27A)
    static let success = Color.fromHex(0x55D6A5)
    static let danger = Color.fromHex(0xD9545D)
    static let star = Color.fromHex(0x73879A)
    static let ship = Color.fromHex(0x34495A)
    static let bridge = Color.fromHex(0x243B4A)
    static let room = Color.fromHex(0x28323C)
    static let drill = Color.fromHex(0x3D3429)
    static let power = Color.fromHex(0x3B292C)
    static let corridor = Color.fromHex(0x53616D)
    static let player = Color.fromHex(0x62C7FF)
}
