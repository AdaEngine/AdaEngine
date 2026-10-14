import AdaCorePipelines
import AdaECS
@testable import AdaPlatform
@_spi(Internal) import AdaRender
import AdaText
@testable import AdaUI
import AdaUtils
import Math
import Testing

private struct LiquidGlassNavigationTabRoot: View {
    @State var selected = 0
    var thirdTabPlacement: TabPlacement = .bar

    var body: some View {
        NavigationStack {
            TabView(selection: $selected) {
                Tab("First", value: 0) {
                    Text("First content")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("glass-content-0")
                }
                Tab("Second", value: 1) {
                    ScrollView {
                        Text("Second content").accessibilityIdentifier("glass-content-1")
                    }
                    .accessibilityIdentifier("glass-scroll")
                }
                Tab("Third", value: 2, placement: thirdTabPlacement) {
                    Text("Third content")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("glass-content-2")
                }
            }
            .tabViewPosition(.bottom)
            .tabViewStyle(LiquidGlassTabBarStyle())
            .mask(RectangleShape())
            .background(Color.black)
            .navigationTitle("Project")
            .navigationBarColor(.red)
        }
        .frame(width: 320, height: 480)
    }
}

@MainActor
private final class SideTabActions {
    var selection = 0
    var composerTaps = 0
}

@MainActor
struct LiquidGlassTabBarStyleTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func outerSideTabsDoNotInsetNavigationControlsTwice() throws {
        let tester = ViewTester {
            TabView(selection: .constant(0)) {
                Tab("Studio", value: 0) {
                    NavigationStack {
                        Color.clear.navigationTitle("Studio")
                            .navigationBarTrailingItems {
                                Button("Settings") {}.frame(width: 44, height: 44).accessibilityIdentifier("outer-settings")
                            }
                    }
                }
                Tab("Community", value: 1) { Color.clear }
            }
            .tabViewPosition(.automatic)
            .tabViewStyle(LiquidGlassTabBarStyle(reservesSideSpaceForContent: false))
            .environment(\.displaySafeAreaInsets, EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84))
        }.setSize(Size(width: 466, height: 678))
        tester.containerView.userInterfaceIdiom = .phone
        tester.performLayout()
        let settings = try #require(tester.findNodeByAccessibilityIdentifier("outer-settings")).visualAbsoluteFrame()
        let tab = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Tab.0")).visualAbsoluteFrame()
        #expect(abs(tab.midX - settings.midX) < 0.5)
        #expect(tab.midX == 424)
    }

    @Test(arguments: [false, true])
    func nestedSideTabsShareNavigationStripWithoutCoveringTheComposer(leading: Bool) throws {
        let actions = SideTabActions()
        let tester = ViewTester {
            NavigationStack {
                TabView(selection: Binding(get: { actions.selection }, set: { actions.selection = $0 })) {
                    Tab("Build", value: 0) {
                        Button("Composer") { actions.composerTaps += 1 }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 16)
                            .accessibilityIdentifier("nested-composer")
                    }
                    Tab("Files", value: 1) { Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity) }
                    Tab("Play", value: 2, placement: .floating) { Color.clear }
                }
                .tabViewPosition(.automatic)
                .tabViewStyle(LiquidGlassTabBarStyle())
                .mask(RectangleShape())
                .navigationTitle("Project")
                .navigationBarContentExtendsIntoSideControls()
                .navigationBarTrailingItems {
                    Button("Settings") {}.frame(width: 44, height: 44).accessibilityIdentifier("nested-settings")
                }
            }
            .environment(\.displaySafeAreaInsets, EdgeInsets(top: 0, leading: leading ? 84 : 0, bottom: 34, trailing: leading ? 0 : 84))
        }.setSize(Size(width: 466, height: 678))
        tester.containerView.userInterfaceIdiom = .phone
        tester.containerView.navigationBarControlsTopInset = 173
        tester.performLayout()
        let settings = try #require(tester.findNodeByAccessibilityIdentifier("nested-settings")).visualAbsoluteFrame()
        let build = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Tab.0")).visualAbsoluteFrame()
        let files = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Tab.1")).visualAbsoluteFrame()
        let composer = try #require(tester.findNodeByAccessibilityIdentifier("nested-composer")).visualAbsoluteFrame()
        #expect(abs(build.midX - settings.midX) < 0.5)
        #expect(build.minY - settings.maxY >= 32)
        #expect(leading ? composer.minX >= 84 : composer.maxX <= 382)
        #expect(!composer.intersects(build))
        tester.sendMouseEvent(at: Point(composer.midX, composer.midY), phase: .began)
        tester.sendMouseEvent(at: Point(composer.midX, composer.midY), phase: .ended)
        #expect(actions.composerTaps == 1)
        tester.sendMouseEvent(at: Point(files.midX, files.midY), phase: .began)
        tester.sendMouseEvent(at: Point(files.midX, files.midY), phase: .ended)
        #expect(actions.selection == 1)
    }

    @Test(arguments: [false, true])
    func automaticSideTabsStayInteractiveAndReturnToTheBottom(leading: Bool) throws {
        var selection = 0
        let tester = ViewTester {
            TabView(selection: Binding(get: { selection }, set: { selection = $0 })) {
                Tab("First", value: 0) { Text("First").accessibilityIdentifier("side-content-0") }
                Tab("Second", value: 1) { Text("Second").accessibilityIdentifier("side-content-1") }
                Tab("Third", value: 2, placement: .floating) { Text("Third").accessibilityIdentifier("side-content-2") }
            }
            .tabViewPosition(.automatic)
            .tabViewStyle(LiquidGlassTabBarStyle())
        }.setSize(Size(width: 951, height: 669))
        tester.containerView.userInterfaceIdiom = .phone
        tester.containerView.safeAreaInsets = EdgeInsets(top: 0, leading: leading ? 84 : 0, bottom: 34, trailing: leading ? 0 : 84)
        tester.containerView.navigationBarControlsTopInset = 105
        tester.performLayout()
        let first = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Tab.0")).visualAbsoluteFrame()
        let second = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Tab.1")).visualAbsoluteFrame()
        #expect(abs(first.midX - second.midX) < 0.5)
        #expect(second.minY > first.maxY)
        #expect(first.minY >= 105 + 16 + 108)
        tester.sendMouseEvent(at: Point(second.midX, second.midY), phase: .began)
        tester.sendMouseEvent(at: Point(second.midX, second.midY), phase: .ended)
        #expect(selection == 1)
        #expect(tester.findNodeByAccessibilityIdentifier("side-content-1") != nil)
        tester.containerView.safeAreaInsets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        tester.setSize(Size(width: 390, height: 844)).performLayout()
        let bottom = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Floating.2")).visualAbsoluteFrame()
        #expect(bottom.minY > 650)
        #expect(selection == 1)
        tester.sendMouseEvent(at: Point(bottom.midX, bottom.midY), phase: .began)
        tester.sendMouseEvent(at: Point(bottom.midX, bottom.midY), phase: .ended)
        #expect(selection == 2)
        #expect(tester.findNodeByAccessibilityIdentifier("side-content-2") != nil)
    }

    @Test(arguments: [Float(20), Float(6)])
    func verticalTabsStayAboveBottomCamera(occlusionMargin: Float) throws {
        let tester = ViewTester {
            TabView(selection: .constant(0)) {
                Tab("Build", value: 0) { Color.clear }
                Tab("Files", value: 1) { Color.clear }
            }
            .tabViewPosition(.automatic)
            .tabViewStyle(LiquidGlassTabBarStyle())
            .environment(\.displaySafeAreaInsets, EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 80))
        }.setSize(Size(width: 600, height: 700))
        tester.containerView.userInterfaceIdiom = .phone
        tester.containerView.reservedRegions = [ViewReservedRegion(id: "camera", kind: .occlusion,
            frame: Rect(x: 520, y: 350, width: 80, height: 350),
            margins: EdgeInsets(top: occlusionMargin, leading: 0, bottom: 0, trailing: 0))]
        tester.performLayout()
        let files = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Tab.1")).visualAbsoluteFrame()
        #expect(files.maxY <= 350 - occlusionMargin)
    }

    @Test(arguments: [Float(20), Float(6)])
    func bottomTabBarStaysAtScreenBottomWhenKeyboardAppears(bottomPadding: Float) throws {
        let tester = ViewTester {
            TabView(selection: Binding<Int>(get: { 0 }, set: { _ in })) {
                Tab("Build", value: 0) {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Tab("Play", value: 1, placement: .floating) {
                    Color.clear
                }
            }
            .tabViewPosition(.bottom)
            .tabViewStyle(LiquidGlassTabBarStyle(bottomPadding: bottomPadding))
        }
        .setSize(Size(width: 390, height: 844))
        tester.containerView.safeAreaInsets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        tester.performLayout()
        let original = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Floating.1")).visualAbsoluteFrame()

        tester.containerView.keyboardOccludedHeight = 301
        tester.performLayout()
        let withKeyboard = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Floating.1")).visualAbsoluteFrame()
        #expect(abs(original.minY - withKeyboard.minY) < 0.5)

        tester.containerView.keyboardOccludedHeight = 0
        tester.performLayout()
        let restored = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Floating.1")).visualAbsoluteFrame()
        #expect(abs(original.minY - restored.minY) < 0.5)
    }

    @Test
    func switchingTabsKeepsSelectedContentAndNavigationChrome() async throws {
        let root = LiquidGlassNavigationTabRoot()
        let tester = ViewTester(rootView: root)
            .setSize(Size(width: 320, height: 480))
            .performLayout()
        let rect = Rect(origin: .zero, size: Size(width: 320, height: 480))
        let world = makeRenderWorld()

        for selected in [0, 1, 2, 0, 2, 1, 0] {
            let point = Point(82 + Float(selected) * 78, 426)
            tester.sendMouseEvent(at: point, phase: .began)
            tester.sendMouseEvent(at: point, phase: .ended)
            await Task.yield()
            tester.advanceFrame(deltaTime: 0.4).performLayout()

            #expect(root.selected == selected)
            #expect(tester.collectHitAccessibilityIdentifiers(in: rect).contains("glass-content-\(selected)"))
            let title = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.NavigationBar.Title"))
            #expect(title.frame.height > 0)
            if selected == 1 {
                let scroll = try #require(tester.findNodeByAccessibilityIdentifier("glass-scroll") as? ScrollViewNode)
                #expect(scroll.environment.safeAreaInsets.top == 92)
                #expect(scroll.absoluteFrame().minY == 0)
            }
            let context = UIGraphicsContext()
            tester.containerView.draw(in: rect, with: context)
            #expect(context.getDrawCommands().contains { command in
                if case let .drawLinearGradient(_, _, _, stops) = command {
                    return stops.first?.color == Color.red.opacity(0.98)
                }
                return false
            })
            var pending = PendingUIGraphicsContext()
            pending.graphicContexts.append(context)
            world.insertResource(pending)
            world.insertResource(UIRenderBuildState())
            await world.runScheduler(.update)
            let items = try #require(world.getResource(RenderItems<UITransparentRenderItem>.self)).items
            #expect(items.contains { !$0.drawData.gradientVertexBuffer.elements.isEmpty })
        }
    }

    @Test
    func draggingRetainsLensOpticsAndRepeatedlySelectsContent() throws {
        let root = LiquidGlassNavigationTabRoot(thirdTabPlacement: .floating)
        let tester = ViewTester(rootView: root).setSize(Size(width: 320, height: 480)).performLayout()
        let selector = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.GlassSelector"))
        let lens = try #require(findGlass(in: selector))

        for target in [1, 0, 1, 0] {
            let start = Point(82 + Float(root.selected) * 78, 426)
            let direction: Float = target == 1 ? 1 : -1
            tester.sendMouseEvent(at: start, phase: .began, time: 0)
            tester.sendMouseEvent(at: Point(start.x + direction * 20, start.y), phase: .changed, time: 0.3)
            tester.advanceFrame(deltaTime: 0.4).performLayout()

            #expect(lens.configuration.blurRadius == 1)
            #expect(lens.configuration.refractiveIndex == 1.28)
            #expect(lens.configuration.dispersionStrength == 0.90)
            #expect(lens.configuration.fresnelIntensity == 0.98)
            #expect(lens.configuration.glareIntensity == 0.92)
            #expect(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.GlassSelector") === selector)

            let end = Point(start.x + direction * 78, start.y)
            tester.sendMouseEvent(at: end, phase: .changed, time: 0.5)
            tester.sendMouseEvent(at: end, phase: .ended, time: 0.6)
            tester.advanceFrame(deltaTime: 0.4).performLayout()
            #expect(root.selected == target)
            #expect(tester.findNodeByAccessibilityIdentifier("glass-content-\(target)") != nil)
            #expect(lens.configuration.blurRadius == Glass.regular.blurRadius)
        }
    }

    private func findGlass(in node: ViewNode) -> GlassEffectViewNode? {
        if let glass = node as? GlassEffectViewNode { return glass }
        for child in node.transientEnvironmentChildren {
            if let glass = findGlass(in: child) { return glass }
        }
        return nil
    }

    @Test
    func floatingTabSelectsItsContentAndReturnsToMainTabs() async throws {
        let root = LiquidGlassNavigationTabRoot(thirdTabPlacement: .floating)
        let tester = ViewTester(rootView: root)
            .setSize(Size(width: 320, height: 480))
            .performLayout()
        let rect = Rect(origin: .zero, size: Size(width: 320, height: 480))
        let floating = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.TabView.Floating.2"))
        let frame = floating.absoluteFrame()
        #expect(frame.width == 68)
        #expect(frame.height == 68)
        #expect(frame.minX > 200)

        for (selected, point) in [(2, Point(frame.midX, frame.midY)), (1, Point(159, 426)), (2, Point(frame.midX, frame.midY)), (0, Point(81, 426))] {
            tester.sendMouseEvent(at: point, phase: .began)
            tester.sendMouseEvent(at: point, phase: .ended)
            await Task.yield()
            tester.advanceFrame(deltaTime: 0.4).performLayout()

            #expect(root.selected == selected)
            #expect(tester.collectHitAccessibilityIdentifiers(in: rect).contains("glass-content-\(selected)"))
            #expect(tester.findNodeByAccessibilityIdentifier("AdaUI.NavigationBar.Title") != nil)
        }
    }

    private func makeRenderWorld() -> World {
        let world = World(name: "LiquidGlassTabBarStyleTests")
        world.setSchedulers([.update])
        world.insertResource(RenderDeviceHandler(renderDevice: unsafe RenderEngine.shared.renderDevice))
        world.insertResource(RenderPipelines(configurator: TextPipeline()))
        world.insertResource(RenderPipelines(configurator: QuadPipeline()))
        world.insertResource(RenderPipelines(configurator: CirclePipeline()))
        world.insertResource(RenderPipelines(configurator: LinePipeline()))
        world.insertResource(RenderPipelines(configurator: LinearGradientPipeline()))
        world.insertResource(RenderPipelines(configurator: GlassPipeline()))
        world.insertResource(UIRenderPipelines(from: world))
        world.insertResource(RenderItems<UITransparentRenderItem>())
        world.insertResource(UIDrawPass())
        world.insertResource(UILayerDrawCache())
        world.insertResource(PendingUIGraphicsContext())
        world.insertResource(UIRenderBuildState())
        world.addSystem(UIRenderTesselationSystem.self)
        return world
    }
}
