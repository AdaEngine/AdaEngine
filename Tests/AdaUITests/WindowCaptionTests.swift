import AdaInput
@testable import AdaPlatform
@_spi(Internal) @testable import AdaUI
import Math
import Testing
#if os(Windows)
import WinSDK
#endif

@MainActor
struct WindowCaptionTests {
    init() async throws { try Application.prepareForTest() }

    @Test func captionControlsRespectWindowResizability() {
        let tester = ViewTester {
            WindowCaptionControls()
                .environment(\.windowCaption, WindowCaptionPresentation(isVisible: true, isResizable: false))
        }.setSize(Size(width: 640, height: 32)).performLayout()
        #expect(tester.findNodeByAccessibilityIdentifier("AdaUI.Caption.Minimize") != nil)
        #expect(tester.findNodeByAccessibilityIdentifier("AdaUI.Caption.Maximize") == nil)
        #expect(tester.findNodeByAccessibilityIdentifier("AdaUI.Caption.Close") != nil)
    }

    #if os(Windows) || os(Linux)
    @Test func captionMenuReceivesInputWhileEmptySpaceAllowsDragging() throws {
        let menu = UIMenu(title: "File")
        menu.add(MenuItem(title: "Open"))
        let tester = ViewTester {
            Text("Content").menuBar(menu)
                .environment(\.windowCaption, WindowCaptionPresentation(isVisible: true))
        }.setSize(Size(width: 640, height: 400)).performLayout()
        let menuNode = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.MenuBar." + menu.id))
        let menuFrame = menuNode.absoluteFrame()
        let point = Point(x: menuFrame.midX, y: menuFrame.midY)
        let event = MouseEvent(window: .empty, button: .left, mousePosition: point, phase: .began, modifierKeys: [], time: 0)
        #expect(!tester.containerView.uiAllowsWindowDrag(at: point, with: event))
        #expect(tester.containerView.uiAllowsWindowDrag(at: Point(x: 300, y: 16), with: event))
        let maximize = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.Caption.Maximize"))
        #expect(maximize.absoluteFrame().width == 46)
        #expect(maximize.absoluteFrame().height == 32)
    }
    #endif

    #if os(Windows)
    @Test func nativeFrameHitTestingPreservesMenusResizeAndSnapRegions() throws {
        var windowClass = WNDCLASSW()
        windowClass.lpfnWndProc = captionTestWindowProcedure
        windowClass.hInstance = GetModuleHandleW(nil)
        let className = Array("AdaCaptionRegressionWindow".utf16) + [0]
        try className.withUnsafeBufferPointer { name in
            windowClass.lpszClassName = name.baseAddress
            #expect(RegisterClassW(&windowClass) != 0)
            defer { UnregisterClassW(name.baseAddress, windowClass.hInstance) }
            let handle = try #require(CreateWindowExW(0, name.baseAddress, nil, DWORD(WS_OVERLAPPEDWINDOW), -200, 50, 640, 400, nil, nil, windowClass.hInstance, nil))
            let key = UInt(bitPattern: handle)
            defer {
                DestroyWindow(handle)
                windowsTitleBars.withLock { $0.removeValue(forKey: key) }
            }
            windowsTitleBars.withLock {
                $0[key] = WindowsTitleBarLayout(height: 32,
                    inputRegions: [Rect(x: 0, y: 0, width: 80, height: 32)],
                    maximizeButton: Rect(x: 400, y: 0, width: 46, height: 32))
            }
            SetWindowPos(handle, nil, 0, 0, 0, 0, UINT(SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE))
            let scale = Float(GetDpiForWindow(handle)) / 96
            func hit(_ x: Float, _ y: Float) -> LRESULT {
                var point = POINT(x: LONG(x * scale), y: LONG(y * scale))
                ClientToScreen(handle, &point)
                let packed = UInt32(UInt16(truncatingIfNeeded: point.x)) | (UInt32(UInt16(truncatingIfNeeded: point.y)) << 16)
                return SendMessageW(handle, UINT(WM_NCHITTEST), 0, LPARAM(packed))
            }
            #expect(hit(40, 16) == LRESULT(HTCLIENT))
            #expect(hit(200, 16) == LRESULT(HTCAPTION))
            #expect(hit(200, 60) == LRESULT(HTCLIENT))
            #expect(hit(420, 16) == LRESULT(HTMAXBUTTON))
            #expect(hit(200, 1) == LRESULT(HTTOP))
            SendMessageW(handle, UINT(WM_NCLBUTTONDOWN), WPARAM(HTMAXBUTTON), 0)
            #expect(windowsTitleBars.withLock { $0[key]?.maximizePressed } == true)
            SendMessageW(handle, UINT(WM_CANCELMODE), 0, 0)
            #expect(windowsTitleBars.withLock { $0[key]?.maximizePressed } == false)
        }
    }

    @Test func hostingWindowPublishesInputRegionsAndReceivesCaptionCommands() throws {
        let window = UIWindow(configuration: .init(
            frame: Rect(x: 0, y: 0, width: 640, height: 400),
            titleBar: .init(background: .transparent, reservesSafeArea: false, dragRegionHeight: 32)
        ))
        let nativeWindow = CaptionRecordingWindow()
        window.systemWindow = nativeWindow
        let menu = UIMenu(title: "File")
        let tester = ViewTester { Text("Content").menuBar(menu) }
            .setSize(Size(width: 640, height: 400))
        window.addSubview(tester.containerView)
        tester.performLayout()
        let minimize = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.Caption.Minimize"))
        let frame = minimize.absoluteFrame()
        let point = Point(x: frame.midX, y: frame.midY)
        #expect(frame.minY == 0)
        #expect(nativeWindow.inputRegions.contains { $0.contains(point: point) })
        #expect(nativeWindow.maximizeButton != nil)
        tester.sendMouseEvent(at: point, phase: .began)
        tester.sendMouseEvent(at: point, phase: .ended)
        #expect(nativeWindow.actions == [.minimize])
        let originalRegions = nativeWindow.inputRegions
        let embeddedPanel = UIContainerView(rootView: Text("Embedded panel"))
        embeddedPanel.frame = Rect(x: 0, y: 80, width: 300, height: 200)
        tester.containerView.addSubview(embeddedPanel)
        embeddedPanel.layoutSubviews()
        #expect(nativeWindow.inputRegions == originalRegions)
    }

    @Test func nativeCaptionDragRegionsExcludeControlsAndContent() {
        let layout = WindowsTitleBarLayout(height: 32, inputRegions: [Rect(x: 0, y: 0, width: 80, height: 32)])
        #expect(!layout.allowsDrag(at: Point(x: 40, y: 16)))
        #expect(layout.allowsDrag(at: Point(x: 200, y: 16)))
        #expect(!layout.allowsDrag(at: Point(x: 200, y: 50)))
        #expect(!layout.allowsDrag(at: Point(x: 200, y: -1)))
    }
    #endif
}

#if os(Windows)
private let captionTestWindowProcedure: WNDPROC = { window, message, wParam, lParam in
    guard let window else { return DefWindowProcW(window, message, wParam, lParam) }
    return windowsTitleBarMessage(hwnd: window, message: message, wParam: wParam, lParam: lParam)
        ?? DefWindowProcW(window, message, wParam, lParam)
}

@MainActor
private final class CaptionRecordingWindow: SystemWindow {
    var title = "Caption test"
    var size = Size(width: 640, height: 400)
    var position = Point.zero
    var inputRegions: [Rect] = []
    var maximizeButton: Rect?
    var actions: [WindowCaptionAction] = []

    func updateTitleBarInputRegions(_ regions: [Rect], maximizeButton: Rect?) {
        inputRegions = regions
        self.maximizeButton = maximizeButton
    }

    func performCaptionAction(_ action: WindowCaptionAction) { actions.append(action) }
}
#endif
