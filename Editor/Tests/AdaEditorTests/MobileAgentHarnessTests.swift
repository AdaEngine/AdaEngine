@testable import AdaEditor
import Foundation
import Testing

@MainActor
@Suite("Mobile agent harness")
struct MobileAgentHarnessTests {
    @Test("Imported instructions persist, can be disabled, and are removed from future turns")
    func skillLifecycle() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("SKILL.md")
        let content = "---\nname: level-design\ndescription: Design compact levels\n---\nUse three rooms and one goal."
        try content.write(to: source, atomically: true, encoding: .utf8)
        let store = MobileAgentHarnessStore(directoryURL: directory.appendingPathComponent("store"))
        let skill = try store.install(from: source)
        try FileManager.default.removeItem(at: source)
        let reloaded = MobileAgentHarnessStore(directoryURL: directory.appendingPathComponent("store"))
        #expect(reloaded.errorMessage == nil)
        #expect(reloaded.settings.installedSkills.first?.summary == "Design compact levels")
        #expect(!reloaded.settings.prompt("Create a maze").contains(content))
        #expect(reloaded.settings.prompt("Create a maze").contains(skill.toolID))
        try reloaded.setEnabled(false, skillID: skill.id)
        let disabled = MobileAgentHarnessStore(directoryURL: directory.appendingPathComponent("store"))
        #expect(!disabled.settings.prompt("Create a maze").contains(content))
        #expect(!disabled.settings.prompt("Create a maze").contains(skill.toolID))
        try disabled.setEnabled(true, skillID: skill.id)
        #expect(disabled.settings.prompt("Create a maze").contains(skill.toolID))
        try disabled.remove(skillID: skill.id)
        #expect(disabled.settings.installedSkills.isEmpty)
        #expect(MobileAgentHarnessStore(directoryURL: directory.appendingPathComponent("store")).settings.installedSkills.isEmpty)
    }

    @Test("A maximum-size installed skill library does not inflate ordinary or repair requests")
    func largeSkillCatalog() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MobileAgentHarnessStore(directoryURL: directory)
        var settings = store.settings
        settings.installedSkills = (0..<4).map { index in
            .init(
                id: "large-\(index)",
                name: String(repeating: "Name ", count: 1000),
                summary: String(repeating: "Description\n", count: 1000),
                content: String(repeating: "x", count: 64 * 1024)
            )
        }
        try store.save(settings)
        let reloaded = MobileAgentHarnessStore(directoryURL: directory).settings
        for request in ["привет", "[Automatic validation feedback]\nFix build errors."] {
            let prompt = MobileEditorAgentContext.prompt(reloaded.prompt(request), visiblePrompt: request)
            #expect(prompt.utf8.count < 4_000)
            for skill in reloaded.installedSkills {
                #expect(prompt.contains(skill.toolID))
                #expect(!prompt.contains(skill.content))
            }
            #expect(MobileEditorAgentContext.visibleText(prompt) == request)
        }
    }

    @Test("Loop settings and instructions survive relaunch and stay present on repair turns")
    func runSettings() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MobileAgentHarnessStore(directoryURL: directory)
        var settings = store.settings
        settings.instructions = "Answer in Russian."
        settings.maxToolRounds = 20
        settings.repairAttempts = 0
        settings.opensPreview = true
        settings.disabledSkillIDs = Set(MobileAgentHarnessSkill.builtIns.map(\.id))
        try store.save(settings)
        let loaded = MobileAgentHarnessStore(directoryURL: directory).settings
        #expect(loaded == settings)
        #expect(loaded.enabledSkills.isEmpty)
        #expect(loaded.prompt("Fix errors").contains("Answer in Russian."))
        #expect(loaded.prompt("Fix errors").hasSuffix("[User request]\nFix errors"))
        let snapshot = store.settings
        settings.instructions = "Use English."
        try store.save(settings)
        #expect(snapshot.prompt("Continue").contains("Answer in Russian."))
    }

    @Test("Invalid, oversized and duplicate imports preserve installed skills")
    func invalidImports() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MobileAgentHarnessStore(directoryURL: directory.appendingPathComponent("store"))
        let file = directory.appendingPathComponent("Custom.md")
        try "Keep scenes small.".write(to: file, atomically: true, encoding: .utf8)
        #expect(try store.install(from: file).name == "Custom")
        let before = store.settings
        #expect(throws: MobileAgentHarnessStore.HarnessError.self) { try store.install(from: file) }
        try Data(repeating: 65, count: 65 * 1024).write(to: file)
        #expect(throws: MobileAgentHarnessStore.HarnessError.self) { try store.install(from: file) }
        try Data([0xff, 0xfe]).write(to: file)
        #expect(throws: MobileAgentHarnessStore.HarnessError.self) { try store.install(from: file) }
        #expect(store.settings == before)
        #expect(MobileAgentHarnessStore(directoryURL: directory.appendingPathComponent("store")).settings == before)
    }

    @Test("Invalid limits and a failed disk write do not change the active configuration")
    func failedSave() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MobileAgentHarnessStore(directoryURL: directory.appendingPathComponent("store"))
        let before = store.settings
        var invalid = before
        invalid.maxToolRounds = 201
        #expect(throws: MobileAgentHarnessStore.HarnessError.self) { try store.save(invalid) }
        #expect(store.settings == before)
        let blocked = directory.appendingPathComponent("blocked")
        try Data().write(to: blocked)
        let blockedStore = MobileAgentHarnessStore(directoryURL: blocked)
        var valid = before
        valid.instructions = "New instructions"
        #expect(throws: (any Error).self) { try blockedStore.save(valid) }
        #expect(blockedStore.settings == before)
    }

    @Test("Corrupt saved settings surface an error without overwriting the file")
    func corruptedSettings() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("settings.json")
        let data = Data("broken settings".utf8)
        try data.write(to: file)
        let store = MobileAgentHarnessStore(directoryURL: directory)
        #expect(store.errorMessage != nil)
        #expect(store.settings == MobileAgentHarnessSettings())
        #expect(try Data(contentsOf: file) == data)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MobileHarnessTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
