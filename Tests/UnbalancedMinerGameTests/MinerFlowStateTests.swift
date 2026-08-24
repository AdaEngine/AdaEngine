import Testing
@testable import UnbalancedMinerGame

@Suite("Unbalanced Miner flow")
struct MinerFlowStateTests {
    @Test("The game starts in the menu")
    func startsInMenu() {
        let flow = MinerFlowState()

        #expect(flow.screen == .menu)
    }

    @Test("The regular flow advances from menu to intro to gameplay")
    func regularFlow() {
        var flow = MinerFlowState()

        flow.start()
        #expect(flow.screen == .intro)

        flow.finishIntro()
        #expect(flow.screen == .gameplay)
    }

    @Test("Repeated transitions cannot skip screens")
    func repeatedTransitionsAreIgnored() {
        var flow = MinerFlowState()

        flow.finishIntro()
        #expect(flow.screen == .menu)

        flow.start()
        flow.start()
        #expect(flow.screen == .intro)

        flow.finishIntro()
        flow.finishIntro()
        #expect(flow.screen == .gameplay)
    }

    @Test("Returning to the menu resets the visible flow")
    func returnsToMenu() {
        var flow = MinerFlowState()
        flow.start()
        flow.finishIntro()

        flow.returnToMenu()

        #expect(flow.screen == .menu)
    }
}
