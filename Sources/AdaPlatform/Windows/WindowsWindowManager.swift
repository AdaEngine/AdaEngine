//
//  WindowsWindowManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/29/22.
//

#if os(Windows)
import AdaRender
@_spi(Internal) import AdaUI
import WinSDK
import AdaInput
import Math
import AdaUtils

final class WindowsWindowManager: UIWindowManager {

    private unowned let screenManager: WindowsScreenManager
    private var windowHandles: [UIWindow.ID: HWND] = [:]

    init(_ screenManager: WindowsScreenManager) {
        self.screenManager = screenManager
        super.init()
    }

    override func createWindow(for window: UIWindow) {
        let minSize = UIWindow.defaultMinimumSize
        
        let frame = window.frame
        let size = frame.size == .zero ? minSize : frame.size
        
        let width = Int32(size.width)
        let height = Int32(size.height)
        
        // Create Windows surface for rendering
        let windowsSurface = WindowsSurface(windowId: window.id)
        let sizeInt = SizeInt(width: Int(size.width), height: Int(size.height))
        try? RenderEngine.shared.createWindow(window.id, for: windowsSurface, size: sizeInt)
        
        // Create Win32 window
        let className = "AdaEngineWindow"
        let hInstance = unsafe GetModuleHandleW(nil)
        
        // Register window class if not already registered
        var wc = unsafe WNDCLASSW()
        unsafe wc.lpfnWndProc = unsafe WindowsWindowProc
        unsafe wc.hInstance = unsafe hInstance
        wc.lpszClassName = className.wide
        wc.hCursor = LoadCursorW(nil, IDC_ARROW)
        wc.hbrBackground = HBRUSH(COLOR_WINDOW + 1)
        RegisterClassW(&wc)
        
        // Calculate window size including non-client area
        var rect = RECT(left: 0, top: 0, right: width, bottom: height)
        AdjustWindowRect(&rect, DWORD(WS_OVERLAPPEDWINDOW), false)
        let windowWidth = rect.right - rect.left
        let windowHeight = rect.bottom - rect.top
        
        let hwnd = CreateWindowExW(
            0,
            className.wide,
            window.title.wide,
            DWORD(WS_OVERLAPPEDWINDOW),
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            windowWidth,
            windowHeight,
            nil,
            nil,
            hInstance,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let hwnd else {
            fatalError("Failed to create window")
        }
        
        // Store window handle
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, LONG_PTR(bitPattern: Unmanaged.passUnretained(window).toOpaque()))
        self.windowHandles[window.id] = hwnd
        
        let systemWindow = WindowsSystemWindow(hwnd: hwnd, surface: windowsSurface)
        window.systemWindow = systemWindow
        window.minSize = minSize
        
        super.createWindow(for: window)
    }

    override func showWindow(_ window: UIWindow, isFocused: Bool) {
        guard let systemWindow = window.systemWindow as? WindowsSystemWindow else {
            fatalError("System window not exist.")
        }
        
        if isFocused {
            unsafe ShowWindow(systemWindow.hwnd, SW_SHOW)
            unsafe SetForegroundWindow(systemWindow.hwnd)
            unsafe SetFocus(systemWindow.hwnd)
        } else {
            unsafe ShowWindow(systemWindow.hwnd, SW_SHOWNOACTIVATE)
        }
        
        window.windowDidAppear()
        self.setActiveWindow(window)
    }
    
    override func setWindowMode(_ window: UIWindow, mode: UIWindow.Mode) {
        guard let systemWindow = window.systemWindow as? WindowsSystemWindow else {
            fatalError("System window not exist.")
        }
        
        let hwnd = unsafe systemWindow.hwnd
        let style = unsafe GetWindowLongW(hwnd, GWL_STYLE)
        
        switch mode {
        case .windowed:
            if window.isFullscreen {
                unsafe SetWindowLongW(hwnd, GWL_STYLE, style | Int32(WS_OVERLAPPEDWINDOW))
                unsafe ShowWindow(hwnd, SW_RESTORE)
                window.isFullscreen = false
            }
        case .fullscreen:
            if !window.isFullscreen {
                unsafe SetWindowLongW(hwnd, GWL_STYLE, style & ~Int32(WS_OVERLAPPEDWINDOW))
                unsafe ShowWindow(hwnd, SW_MAXIMIZE)
                window.isFullscreen = true
            }
        }
    }
    
    override func closeWindow(_ window: UIWindow) {
        guard let systemWindow = window.systemWindow as? WindowsSystemWindow else {
            fatalError("System window not exist.")
        }

        self.removeWindow(window, setActiveAnotherIfNeeded: true)
        unsafe DestroyWindow(systemWindow.hwnd)
    }
    
    override func resizeWindow(_ window: UIWindow, size: Size) {
        guard let systemWindow = window.systemWindow as? WindowsSystemWindow else {
            return
        }
        
        var rect = RECT()
        unsafe GetClientRect(systemWindow.hwnd, &rect)
        rect.right = LONG(size.width)
        rect.bottom = LONG(size.height)
        
        unsafe AdjustWindowRect(&rect, DWORD(WS_OVERLAPPEDWINDOW), false)
        unsafe SetWindowPos(
            systemWindow.hwnd,
            nil,
            0, 0,
            rect.right - rect.left,
            rect.bottom - rect.top,
            UINT(SWP_NOMOVE | SWP_NOZORDER)
        )
    }
    
    override func setMinimumSize(_ size: Size, for window: UIWindow) {
        guard let systemWindow = window.systemWindow as? WindowsSystemWindow else {
            fatalError("System window not exist.")
        }
        
        // Store minimum size - will be enforced in window proc
        // This is a simplified implementation
    }
    
    override func getScreen(for window: UIWindow) -> Screen? {
        guard let systemWindow = window.systemWindow as? WindowsSystemWindow else {
            return nil
        }
        
        guard let hMonitor = unsafe MonitorFromWindow(systemWindow.hwnd, UInt32(MONITOR_DEFAULTTONEAREST)) else {
            return nil
        }
        return unsafe screenManager.makeScreen(from: hMonitor)
    }
    
    override func setCursorShape(_ shape: Input.CursorShape) {
        // TODO: Implement cursor shape changes
    }
    
    override func updateCursor() {
        // TODO: Implement cursor updates
    }
    
    override func getCursorShape() -> Input.CursorShape {
        return .arrow
    }
    
    override func setCursorImage(for shape: Input.CursorShape, texture: Texture2D?, hotspot: Vector2) {
        // TODO: Implement custom cursor images
    }
    
    override func setMouseMode(_ mode: Input.MouseMode) {
        // TODO: Implement mouse mode changes
    }
    
    override func getMouseMode() -> Input.MouseMode {
        return .visible
    }
    
    func findWindow(for hwnd: HWND) -> UIWindow? {
        return self.windows.first {
            if let systemWindow = $0.systemWindow as? WindowsSystemWindow {
                return unsafe systemWindow.hwnd == hwnd
            }
            return false
        }
    }
}

// MARK: - Windows Window Procedure

private func WindowsWindowProc(hwnd: HWND?, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT {
    guard let hwnd else {
        return unsafe DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
    
    // Get window from user data
    let windowPtr = unsafe GetWindowLongPtrW(hwnd, GWLP_USERDATA)
    guard windowPtr != 0 else {
        return unsafe DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
    
    guard let rawPtr = UnsafeRawPointer(bitPattern: Int(windowPtr)),
          let window = Unmanaged<UIWindow>.fromOpaque(rawPtr).takeUnretainedValue() as? UIWindow else {
        return unsafe DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
    
    let windowManager = window.windowManager as? WindowsWindowManager
    
    switch uMsg {
    case UInt32(WM_CLOSE):
        if window.windowShouldClose() {
            return 0
        }
        return unsafe DefWindowProcW(hwnd, uMsg, wParam, lParam)
        
    case UInt32(WM_SIZE):
        let width = LOWORD(lParam)
        let height = HIWORD(lParam)
        let newSize = Size(width: Float(width), height: Float(height))
        
        if window.frame.size != newSize {
            window.frame = Rect(origin: .zero, size: newSize)
        }
        
        let sizeInt = SizeInt(width: Int(width), height: Int(height))
        try? RenderEngine.shared.resizeWindow(window.id, newSize: sizeInt)
        return 0
        
    case WM_SETFOCUS:
        windowManager?.setActiveWindow(window)
        return 0
        
    case WM_KILLFOCUS:
        window.windowDidResignActive()
        return 0
        
    default:
        return DefWindowProcW(hwnd, uMsg, wParam, lParam)
    }
}

// MARK: - WindowsSystemWindow

final class WindowsSystemWindow: SystemWindow {
    let hwnd: HWND
    let surface: WindowsSurface
    
    init(hwnd: HWND, surface: WindowsSurface) {
        self.hwnd = hwnd
        self.surface = surface
    }
    
    var title: String {
        get {
            var buffer = [WCHAR](repeating: 0, count: 256)
            GetWindowTextW(hwnd, &buffer, 256)
            return String(decodingCString: buffer, as: UTF16.self)
        }
        set {
            SetWindowTextW(hwnd, newValue.wide)
        }
    }
    
    var size: Size {
        get {
            var rect = RECT()
            GetClientRect(hwnd, &rect)
            return Size(width: Float(rect.right - rect.left), height: Float(rect.bottom - rect.top))
        }
        set {
            var rect = RECT(left: 0, top: 0, right: LONG(newValue.width), bottom: LONG(newValue.height))
            AdjustWindowRect(&rect, DWORD(WS_OVERLAPPEDWINDOW), false)
            SetWindowPos(hwnd, nil, 0, 0, rect.right - rect.left, rect.bottom - rect.top, UINT(SWP_NOMOVE | SWP_NOZORDER))
        }
    }
    
    var position: Point {
        get {
            var rect = RECT()
            GetWindowRect(hwnd, &rect)
            return Point(x: Float(rect.left), y: Float(rect.top))
        }
        set {
            SetWindowPos(hwnd, nil, LONG(newValue.x), LONG(newValue.y), 0, 0, UINT(SWP_NOSIZE | SWP_NOZORDER))
        }
    }
}

// MARK: - WindowsScreenManager

final class WindowsScreenManager: ScreenManager {
    func getMainScreen() -> Screen? {
        guard let hMonitor = MonitorFromWindow(nil, UInt32(MONITOR_DEFAULTTOPRIMARY)) else {
            return nil
        }
        return makeScreen(from: hMonitor)
    }
    
    func getScreens() -> [Screen] {
        class ScreensCollector {
            var screens: [Screen] = []
        }
        
        let collector = ScreensCollector()
        let collectorPtr = Unmanaged.passUnretained(collector).toOpaque()
        
        EnumDisplayMonitors(nil, nil, { hMonitor, _, _, lParam in
            guard let hMonitor = hMonitor, lParam != 0 else {
                return WindowsBool(true)
            }
            let collector = Unmanaged<ScreensCollector>.fromOpaque(UnsafeRawPointer(bitPattern: Int(lParam))!).takeUnretainedValue()
            if let screen = WindowsScreenManager.shared?.makeScreen(from: hMonitor) {
                collector.screens.append(screen)
            }
            return WindowsBool(true)
        }, LPARAM(Int(bitPattern: collectorPtr)))
        
        return collector.screens
    }
    
    func getScreenScale(for screen: Screen) -> Float {
        guard let hMonitor = (screen.systemScreen as? HMONITOR) else {
            return 1.0
        }
        
        var info = MONITORINFO()
        info.cbSize = DWORD(MemoryLayout<MONITORINFO>.size)
        
        if GetMonitorInfoW(hMonitor, &info) {
            // Get DPI for the monitor
            var dpiX: UINT = 0
            var dpiY: UINT = 0
            GetDpiForMonitor(hMonitor, MDT_EFFECTIVE_DPI, &dpiX, &dpiY)
            return Float(dpiX) / 96.0 // 96 DPI is standard
        }
        
        return 1.0
    }
    
    func getSize(for screen: Screen) -> Size {
        guard let hMonitor = (screen.systemScreen as? HMONITOR) else {
            return .zero
        }
        
        var info = MONITORINFO()
        info.cbSize = DWORD(MemoryLayout<MONITORINFO>.size)
        
        if GetMonitorInfoW(hMonitor, &info) {
            let width = Float(info.rcMonitor.right - info.rcMonitor.left)
            let height = Float(info.rcMonitor.bottom - info.rcMonitor.top)
            return Size(width: width, height: height)
        }
        
        return .zero
    }
    
    func getBrightness(for screen: Screen) -> Float {
        // Windows brightness API is complex, return default for now
        return 1.0
    }
    
    func makeScreen(from systemScreen: SystemScreen) -> Screen {
        return Screen(systemScreen: systemScreen, screenManager: self)
    }
    
    func makeScreen(from hMonitor: HMONITOR) -> Screen? {
        return makeScreen(from: hMonitor as SystemScreen)
    }
    
    static var shared: WindowsScreenManager?
}

extension HMONITOR: SystemScreen {}

extension String {
    var wide: [WCHAR] {
        return self.utf8.map { WCHAR($0) } + [0]
    }
}

#endif

