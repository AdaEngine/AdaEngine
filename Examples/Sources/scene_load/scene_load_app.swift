import AdaEngine

@main
struct SceneLoadApp: App {

    init() {
        // Register components to be able to load them from the scene file
        ComponentA.registerComponent()
        ComponentB.registerComponent()
        ComponentC.registerComponent()

        // Register system to be able to load it from the scene file
        PlayerSystem.registerSystem()
    }

    var scene: some AppScene {
        WindowGroup {
            SceneLoadView()
        }
        .windowMode(.windowed)
        .windowTitle("Scene Load")
    }
}

struct SceneLoadView: View {

    var body: some View {
        VStack(spacing: 10) {
            Button("Load Scene", action: loadScene)

            Button("Save Scene", action: saveScene)
        }
    }

    private func loadScene() {
        Task {
            do {
                // Load scene from the bundle in `Resources` directory.
                let scene: Scene = try await AssetsManager.load("TestScene.ascn", from: Bundle.module)
                let entities = scene.world.getEntities()
                print("scene: \(scene.name) entities: \(entities.count)")
                print("entities:", entities.map { 
                    "\n- name: \($0.name)\n  components: -\n\($0.components)\n"
                })
            } catch {
                print("Error: \(error)")
            }
        }
    }

    private func saveScene() {
        let scene = Scene(name: "TestScene")
        scene.world.addEntity(
            Entity(name: "Player") {
                Transform(position: [10, 10, 0])
                ComponentA(value: 10)
                ComponentB(value: "Hello", ignoredValue: .init(wrappedValue: 10))
            }
        )
        scene.world.addEntity(Entity(name: "Enemy") {
            Transform(position: [20, 20, 0])
            ComponentA(value: 20)
            ComponentB(value: "World", ignoredValue: .init(wrappedValue: 20))
        })
        scene.world.addEntity(Entity(name: "Enemy") {
            Transform(position: [30, 30, 0])
            ComponentA(value: 30)
            ComponentC(value: "Enemy 2")
            ComponentB(value: "Enemy", ignoredValue: .init(wrappedValue: 30))
        })

        scene.world.addSystem(PlayerSystem.self)

        Task {
            do {
                // Save scene to the file in the user's downloads directory
                let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path()
                try await AssetsManager.save(scene, at: url, name: "TestScene")
            } catch {
                print("Error: \(error)")
            }
        }
    }
}

@Component
struct ComponentA: Codable {
    var value: Int
}

@Component
struct ComponentB: Codable {
    var value: String

    @NoExport
    var ignoredValue: Int
}

// Component that is not Codable can't be saved to the scene file
@Component
struct ComponentC {
    var value: String
}


extension Int: @retroactive DefaultValue {
    public static var defaultValue: Int {
        return 0
    }
}

struct PlayerSystem: System {

    init(world: World) { }

    func update(context: UpdateContext) { }
}

