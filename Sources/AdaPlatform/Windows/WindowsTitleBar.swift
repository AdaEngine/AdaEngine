#if os(Windows)
import Math
import Synchronization
import WinSDK

/// Immutable snapshots cross from MainActor to the HWND thread. Native hit testing
/// never waits for Swift UI layout, including inside a modal resize loop.
struct WindowsTitleBarLayout: Sendable {
    var height: Float
    var inputRegions: [Rect] = []
    var maximizeButton: Rect?
    var maximizePressed = false

    func allowsDrag(at point: Point) -> Bool {
        point.y >= 0 && point.y < height && !inputRegions.contains { $0.contains(point: point) }
    }
}

let windowsTitleBars = Mutex<[UInt: WindowsTitleBarLayout]>([:])

func windowsTitleBarMessage(hwnd: HWND, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
    guard let layout = windowsTitleBars.withLock({ $0[UInt(bitPattern: hwnd)] }) else { return nil }
    let style = unsafe GetWindowLongW(hwnd, GWL_STYLE)
    // Fullscreen temporarily removes standard window styles.
    guard style & Int32(WS_CAPTION) != 0 else { return nil }
    switch message {
    case UINT(WM_NCCALCSIZE):
        guard wParam != 0,
            let parameters = unsafe UnsafeMutablePointer<NCCALCSIZE_PARAMS>(bitPattern: Int(lParam)) else { return nil }
        let top = unsafe parameters.pointee.rgrc.0.top
        _ = unsafe DefWindowProcW(hwnd, message, wParam, lParam)
        let dpi = unsafe GetDpiForWindow(hwnd)
        let inset = unsafe IsZoomed(hwnd) ? GetSystemMetricsForDpi(SM_CYFRAME, dpi) + GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi) : 0
        unsafe parameters.pointee.rgrc.0.top = top + inset
        return 0
    case UINT(WM_NCHITTEST):
        let nativeHit = unsafe DefWindowProcW(hwnd, message, wParam, lParam)
        if nativeHit >= LRESULT(HTLEFT) && nativeHit <= LRESULT(HTBOTTOMRIGHT) { return nativeHit }
        var point = POINT(x: LONG(Int16(truncatingIfNeeded: lParam)), y: LONG(Int16(truncatingIfNeeded: lParam >> 16)))
        unsafe ScreenToClient(hwnd, &point)
        let scale = Float(unsafe GetDpiForWindow(hwnd)) / 96
        let logical = Point(x: Float(point.x) / scale, y: Float(point.y) / scale)
        if unsafe !IsZoomed(hwnd), style & Int32(WS_THICKFRAME) != 0 {
            let border = unsafe GetSystemMetricsForDpi(SM_CYFRAME, GetDpiForWindow(hwnd))
                + GetSystemMetricsForDpi(SM_CXPADDEDBORDER, GetDpiForWindow(hwnd))
            if point.y < border { return LRESULT(HTTOP) }
        }
        if layout.maximizeButton?.contains(point: logical) == true { return LRESULT(HTMAXBUTTON) }
        return layout.allowsDrag(at: logical) ? LRESULT(HTCAPTION) : LRESULT(HTCLIENT)
    case UINT(WM_NCLBUTTONDOWN):
        if wParam == WPARAM(HTMAXBUTTON) {
            windowsTitleBars.withLock { $0[UInt(bitPattern: hwnd)]?.maximizePressed = true }
            unsafe SetCapture(hwnd)
            return 0
        }
    case UINT(WM_LBUTTONUP):
        if layout.maximizePressed {
            windowsTitleBars.withLock { $0[UInt(bitPattern: hwnd)]?.maximizePressed = false }
            unsafe ReleaseCapture()
            let scale = Float(unsafe GetDpiForWindow(hwnd)) / 96
            let point = Point(x: Float(Int16(truncatingIfNeeded: lParam)) / scale, y: Float(Int16(truncatingIfNeeded: lParam >> 16)) / scale)
            if layout.maximizeButton?.contains(point: point) == true {
                unsafe PostMessageW(hwnd, UINT(WM_SYSCOMMAND), WPARAM(IsZoomed(hwnd) ? SC_RESTORE : SC_MAXIMIZE), 0)
            }
            return 0
        }
    case UINT(WM_CAPTURECHANGED), UINT(WM_CANCELMODE):
        windowsTitleBars.withLock { $0[UInt(bitPattern: hwnd)]?.maximizePressed = false }
    default: break
    }
    return nil
}

/// Removes only the caption's extra height; native resize borders stay intact.
func adjustWindowsClientRect(_ rect: inout RECT, style: DWORD, extendedStyle: DWORD, dpi: UINT, customTitleBar: Bool) {
    unsafe AdjustWindowRectExForDpi(&rect, style, false, extendedStyle, dpi)
    if customTitleBar { rect.top = 0 }
}
#endif
