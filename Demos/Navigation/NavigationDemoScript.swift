import AdaEngine
import Foundation

@Component
struct NavigationDemoPatrolComponent {
    var enabled: Bool = true
    var completedGoals: Int = 0
}

@MainActor
enum NavigationDemoScript {
    static func install(in app: AppWorlds) throws -> AdaScriptPlugin {
        RuntimeTypeRegistry.registerComponent(
            NavigationDemoPatrolComponent.self, names: ["NavigationDemoPatrolComponent"],
            makeDefault: { NavigationDemoPatrolComponent() }
        )
        guard let file = Bundle.module.url(forResource: "NavigationRobot", withExtension: "ada") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let script = try AdaScriptPlugin(source: String(contentsOf: file, encoding: .utf8), name: "NavigationRobot")
        script.setup(in: app)
        return script
    }
}
