import AdaECS
import Foundation
import Testing
@testable import AdaEngine

@MainActor
struct WindowGroupFramePacingTests {
    @Test
    func windowGroupInstallsFramePacing() {
        let appWorlds = AppWorlds(main: World())

        WindowGroupPlugin(content: EmptyView()).setup(in: appWorlds)

        #expect(appWorlds.getResource(ApplicationFramePacing.self)?.maximumFramesPerSecond == 60)
        #expect(appWorlds.getResource(ApplicationFramePacing.self)?.synchronizesWithDisplayRefreshRate == true)
    }

    @Test
    func windowGroupKeepsExistingFramePacing() {
        let appWorlds = AppWorlds(main: World())
        appWorlds.insertResource(ApplicationFramePacing(maximumFramesPerSecond: 30))

        WindowGroupPlugin(content: EmptyView()).setup(in: appWorlds)

        #expect(appWorlds.getResource(ApplicationFramePacing.self)?.maximumFramesPerSecond == 30)
        #expect(appWorlds.getResource(ApplicationFramePacing.self)?.synchronizesWithDisplayRefreshRate == false)
    }

    @Test
    func displaySynchronizedPacingUsesDisplayMaximum() {
        let framePacing = ApplicationFramePacing.displaySynchronized()

        #expect(framePacing.resolvedMaximumFramesPerSecond(forDisplayMaximumFramesPerSecond: 120) == 120)
        #expect(framePacing.resolvedFrameRateRange(forDisplayMaximumFramesPerSecond: 120) == 30...120)
    }

    @Test
    func explicitPacingRespectsConfiguredAndDisplayLimits() {
        let framePacing = ApplicationFramePacing(maximumFramesPerSecond: 60)

        #expect(framePacing.resolvedFrameRateRange(forDisplayMaximumFramesPerSecond: 120) == 30...60)
        #expect(framePacing.resolvedFrameRateRange(forDisplayMaximumFramesPerSecond: 24) == 24...24)
    }

    @Test
    func legacyFramePacingPayloadKeepsFixedRateBehavior() throws {
        let data = try #require(#"{"maximumFramesPerSecond":30}"#.data(using: .utf8))
        let framePacing = try JSONDecoder().decode(ApplicationFramePacing.self, from: data)

        #expect(framePacing.maximumFramesPerSecond == 30)
        #expect(framePacing.synchronizesWithDisplayRefreshRate == false)
    }
}
