import Testing
@testable import StarQuestGame

@MainActor struct StarQuestTests {
    @Test func expeditionCanPauseResumeAndCompleteThroughUIActions() throws {
        let model = try StarQuestModel(defaults: nil)
        model.context.perform("continue")
        #expect(model.screen == .menu)
        model.context.perform("new")
        model.context.perform("collect0")
        model.context.perform("collect0")
        #expect(model.collected.count == 1)
        model.context.perform("pause")
        model.context.perform("collect1")
        #expect(model.collected.count == 1)
        model.context.perform("continue")
        for index in 1..<5 { model.context.perform("collect\(index)") }
        #expect(model.screen == .result)
        #expect(model.best == 5)
        #expect(!model.hasAdventure)
        #expect(model.error == nil)
        #expect(model.context.diagnostics.isEmpty)
    }
    @Test func screensAndSettingsLoadWithRealAssets() throws {
        let model = try StarQuestModel(defaults: nil)
        for action in ["settings", "theme", "size", "home", "credits", "home", "new", "pause", "home"] { model.context.perform(action) }
        #expect(model.alternateBackdrop)
        #expect(model.widePanel)
        #expect(model.hasAdventure)
        #expect(model.session != nil)
        #expect(model.error == nil)
        #expect(model.context.diagnostics.isEmpty)
    }
}
