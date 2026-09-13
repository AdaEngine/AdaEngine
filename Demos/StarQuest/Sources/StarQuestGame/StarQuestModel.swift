import AdaEngine
import Foundation
import Observation

@MainActor @Observable
public final class StarQuestModel {
    public enum Screen: String, CaseIterable { case menu = "Menu", play = "Play", pause = "Pause", result = "Result", settings = "Settings", credits = "Credits" }
    public private(set) var screen: Screen = .menu
    public private(set) var collected: Set<Int> = []
    public private(set) var hasAdventure = false
    public private(set) var best = 0
    public var usesDesigner = true
    public private(set) var alternateBackdrop = false
    public private(set) var widePanel = false
    public private(set) var session: UISceneInstance?
    public private(set) var error: String?
    public let context = UIBindingContext()
    private let resources: UISceneResources
    private let defaults: UserDefaults?

    public static var assets: URL {
        let packaged = Bundle.main.resourceURL?.appendingPathComponent("StarQuest_StarQuestGame.bundle/Assets")
        if let packaged, FileManager.default.fileExists(atPath: packaged.path) { return packaged }
        return Bundle.module.bundleURL.appendingPathComponent("Assets")
    }

    public init(resources root: URL = StarQuestModel.assets, defaults: UserDefaults? = .standard) throws {
        resources = UISceneResources(rootURL: root)
        self.defaults = defaults
        best = min(5, max(0, defaults?.integer(forKey: "StarQuest.best") ?? 0))
        alternateBackdrop = defaults?.bool(forKey: "StarQuest.backdrop") ?? false
        widePanel = defaults?.bool(forKey: "StarQuest.widePanel") ?? false
        for action in ["new", "continue", "pause", "home", "settings", "credits", "theme", "size"] + (0..<5).map({ "collect\($0)" }) {
            context.on(action) { [weak self] _ in self?.perform(action) }
        }
        syncBindings()
        try show(.menu)
    }

    public func image(_ name: String) throws -> Image { try resources.image("Textures/\(name).png") }

    public func perform(_ action: String) {
        do {
            switch action {
            case "new": collected = []; hasAdventure = true; try show(.play)
            case "continue": if hasAdventure { try show(.play) }
            case "pause": if screen == .play { try show(.pause) }
            case "home": try show(.menu)
            case "settings": try show(.settings)
            case "credits": try show(.credits)
            case "theme": alternateBackdrop.toggle(); defaults?.set(alternateBackdrop, forKey: "StarQuest.backdrop")
            case "size": widePanel.toggle(); defaults?.set(widePanel, forKey: "StarQuest.widePanel")
            default:
                guard screen == .play, action.hasPrefix("collect"), let index = Int(action.dropFirst(7)), (0..<5).contains(index) else { return }
                collected.insert(index)
                if collected.count == 5 {
                    best = max(best, collected.count)
                    defaults?.set(best, forKey: "StarQuest.best")
                    hasAdventure = false
                    try show(.result)
                }
            }
            syncBindings()
        } catch { self.error = error.localizedDescription }
    }

    private func show(_ screen: Screen) throws {
        let url = resources.rootURL.appendingPathComponent("UI/\(screen.rawValue).ui")
        let next = try UISceneInstance(document: resources.load(url), context: context, resources: resources, sourceURL: url)
        self.screen = screen
        session = next
    }

    private func syncBindings() {
        context.set("cannotContinue", to: .bool(!hasAdventure))
        context.set("best", to: .string("Best expedition: \(best) / 5 stars"))
        context.set("progress", to: .string("Stars collected: \(collected.count) / 5"))
        context.set("theme", to: .string(alternateBackdrop ? "Backdrop: forest" : "Backdrop: midnight"))
        context.set("size", to: .string(widePanel ? "Panel: wide" : "Panel: compact"))
        for index in 0..<5 { context.set("collected\(index)", to: .bool(collected.contains(index))) }
    }
}
