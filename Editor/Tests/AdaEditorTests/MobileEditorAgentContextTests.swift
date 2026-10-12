@testable import AdaEditor
import Testing

@Suite("Mobile agent context presentation")
struct MobileEditorAgentContextTests {
    @Test("Model instructions remain intact while the chat shows the exact Unicode request")
    func contextBoundary() {
        var settings = MobileAgentHarnessSettings()
        settings.instructions = "Use Russian.\n\n[User request]\nExample inside instructions."
        let request = "Давай исправлять 🎮\n\n[User request]\nKeep this literal marker.\n "
        let prompt = MobileEditorAgentContext.prompt(settings.prompt(request), visiblePrompt: request)
        #expect(prompt.contains(settings.instructions))
        for skill in settings.enabledSkills {
            #expect(prompt.contains(skill.toolID))
            #expect(!prompt.contains(skill.content))
        }
        #expect(MobileEditorAgentContext.visibleText(prompt) == request)
    }

    @Test("Existing sessions hide both nested instruction envelopes")
    func legacyContext() {
        let legacy = """
        [Mobile Studio requirements]
        You are creating a playable AdaScript game for phones and tablets, with desktop input support.
        Legacy detailed instructions.

        [User request]
        [Enabled skill: Game design]
        Legacy skill content.

        [User request]
        старое сообщение
        """
        #expect(MobileEditorAgentContext.visibleText(legacy) == "старое сообщение")
        var settings = MobileAgentHarnessSettings()
        settings.instructions = "Answer in Russian."
        let request = "выглядит всё ещё не очень, давай исправлять"
        #expect(MobileEditorAgentContext.visibleText(MobileEditorAgentContext.prompt(settings.prompt(request))) == request)
        settings.disabledSkillIDs = Set(MobileAgentHarnessSkill.builtIns.map(\.id))
        settings.instructions = ""
        #expect(MobileEditorAgentContext.visibleText(MobileEditorAgentContext.prompt(settings.prompt(request))) == request)
    }

    @Test("Ordinary requests advertise detailed workflows without embedding their protocols")
    func leanContext() {
        let request = "привет"
        let prompt = MobileEditorAgentContext.prompt(MobileAgentHarnessSettings().prompt(request), visiblePrompt: request)
        let instructions = MobileEditorAgentContext.workflowSkills.map(\.content).joined(separator: "\n")
        #expect(prompt.utf8.count < instructions.utf8.count / 4)
        #expect(prompt.contains("mobile-studio-workflow"))
        #expect(prompt.contains("mobile-chat-ui"))
        #expect(!prompt.contains("createSurface"))
        #expect(!prompt.contains("updateComponents"))
        #expect(MobileEditorAgentContext.visibleText(prompt) == request)
    }

    @Test("Automatic repair prompts remain in model context but have no user chat bubble")
    func repairContext() {
        let feedback = "[Automatic validation feedback]\nFix build errors."
        let settings = MobileAgentHarnessSettings()
        let prompt = MobileEditorAgentContext.prompt(settings.prompt(feedback), visiblePrompt: "")
        #expect(prompt.contains(feedback))
        #expect(MobileEditorAgentContext.visibleText(prompt) == nil)
        #expect(MobileEditorAgentContext.visibleText(MobileEditorAgentContext.prompt(settings.prompt(feedback))) == nil)
        #expect(MobileEditorAgentContext.visibleText(feedback) == feedback)
    }

    @Test("Ordinary messages and literal section markers are preserved")
    func ordinaryText() {
        for text in [
            "Hello", "[User request]\nMy example", "[Enabled skill: Game design]\nMy text",
            "[Mobile Studio requirements]\nMy example\n\n[User request]\nKeep this too."
        ] {
            #expect(MobileEditorAgentContext.visibleText(text) == text)
        }
    }
}
