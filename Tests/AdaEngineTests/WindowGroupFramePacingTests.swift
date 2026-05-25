import AdaECS
import Testing
@testable import AdaEngine

@MainActor
struct WindowGroupFramePacingTests {
    @Test
    func windowGroupInstallsFramePacing() {
        let appWorlds = AppWorlds(main: World())

        WindowGroupPlugin(content: EmptyView()).setup(in: appWorlds)

        #expect(appWorlds.getResource(ApplicationFramePacing.self)?.maximumFramesPerSecond == 60)
    }

    @Test
    func windowGroupKeepsExistingFramePacing() {
        let appWorlds = AppWorlds(main: World())
        appWorlds.insertResource(ApplicationFramePacing(maximumFramesPerSecond: 30))

        WindowGroupPlugin(content: EmptyView()).setup(in: appWorlds)

        #expect(appWorlds.getResource(ApplicationFramePacing.self)?.maximumFramesPerSecond == 30)
    }
}
