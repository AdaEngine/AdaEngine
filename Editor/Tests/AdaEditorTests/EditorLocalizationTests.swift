@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Foundation
import Testing

@testable import AdaEditor

@Suite("Studio localization", .serialized)
@MainActor
struct EditorLocalizationTests {
    @Test("System preferences match regional language tags and fall back to English")
    func systemLanguage() {
        #expect(EditorLanguage.resolve(.system, preferredLanguages: ["ru-RU", "en-US"]) == .russian)
        #expect(EditorLanguage.resolve(.system, preferredLanguages: ["ru_RU"]) == .russian)
        #expect(EditorLanguage.resolve(.system, preferredLanguages: ["en-GB", "ru-RU"]) == .english)
        #expect(EditorLanguage.resolve(.system, preferredLanguages: ["fr-FR", "ru"]) == .russian)
        #expect(EditorLanguage.resolve(.system, preferredLanguages: ["fr-FR"]) == .english)
        #expect(EditorLanguage.resolve(.system, preferredLanguages: []) == .english)
        #expect(EditorLanguage.resolve(.english, preferredLanguages: ["ru-RU"]) == .english)
        #expect(EditorLanguage.resolve(.russian, preferredLanguages: ["en-US"]) == .russian)
    }

    @Test("Manual choice persists and System restores automatic selection")
    func persistence() throws {
        let suite = "AdaEditor.Localization.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = EditorLocalization(defaults: defaults, preferredLanguages: ["ru-RU"])
        #expect(settings.preference == .system)
        #expect(settings.language == .russian)
        settings.preference = .english
        let restored = EditorLocalization(defaults: defaults, preferredLanguages: ["ru-RU"])
        #expect(restored.language == .english)
        restored.preference = .system
        #expect(restored.language == .russian)
        defaults.set("unknown-language", forKey: EditorLocalization.preferenceKey)
        #expect(EditorLocalization(defaults: defaults, preferredLanguages: ["ru-RU"]).preference == .system)
    }

    @Test("Bundled catalogs are complete and preserve interpolation placeholders")
    func catalogs() throws {
        let catalog = L10n.catalog
        #expect(catalog.english.count > 1_000)
        #expect(Set(catalog.english.keys) == Set(catalog.russian.keys))
        let placeholders = try NSRegularExpression(pattern: #"\{\d+\}"#)
        for (key, english) in catalog.english {
            let russian = try #require(catalog.russian[key])
            #expect(!russian.isEmpty)
            func arguments(_ text: String) -> [String] {
                placeholders.matches(in: text, range: NSRange(text.startIndex..., in: text))
                    .compactMap { Range($0.range, in: text).map { String(text[$0]) } }.sorted()
            }
            #expect(arguments(english) == arguments(russian), "Placeholder mismatch: \(key)")
        }
        #expect(catalog.string("Settings", language: .russian) == "Настройки")
        #expect(catalog.string("Settings", language: .english) == "Settings")
        #expect(catalog.string("Unregistered key", language: .russian) == "Unregistered key")
        let message: EditorLocalizedMessage = "Close \("мир {1}.ascn")"
        #expect(catalog.string(message.key, language: .russian, arguments: message.arguments) == "Закрыть мир {1}.ascn")
    }

    @Test("Language selection updates an existing settings view")
    func liveSwitch() async throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "StudioLocalization")))
        }
        let previous = EditorLocalization.shared.preference
        defer { EditorLocalization.shared.preference = previous }
        EditorLocalization.shared.preference = .english
        let model = EditorSettingsWindowViewModel(editorViewModel: nil, selectedSection: .general, selectedPage: EditorSettingsPage.language)
        let container = UIContainerView(rootView: EditorSettingsWindowView(viewModel: model).theme(.adaEditor))
        container.frame = Rect(x: 0, y: 0, width: 1_000, height: 720)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Settings.Language.ru"))
        for _ in 0..<10 {
            await Task.yield()
            container.update(1 / 60)
            container.layoutIfNeeded()
        }
        #expect(EditorLocalization.shared.language == .russian)
        #expect(model.selectedPage == EditorSettingsPage.language)
        model.searchText = "язык"
        #expect(model.visiblePages(in: .general) == [EditorSettingsPage.language])
        #expect(L10n.tr("Application language") == "Язык приложения")
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Settings.Language.en"))
        #expect(EditorLocalization.shared.language == .english)
    }
}
