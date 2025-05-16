#if LINUX
import Wayland
import Math

@MainActor
final class WaylandView: SystemWindow {
    private(set) var surface: OpaquePointer?
    private(set) var shellSurface: OpaquePointer?
    private(set) var window: OpaquePointer?
    private var frame: Rect
    private var _title: String = ""
    private var _position: Point = .zero
    private var _minSize: Size = .zero

    weak var windowManager: LinuxWindowManager?
    
    let windowId: UIWindow.ID
    
    init(
        windowId: UIWindow.ID, 
        frame: Rect,
        windowManager: LinuxWindowManager
    ) {
        self.windowId = windowId
        self.frame = frame
        self.windowManager = windowManager
        setupWaylandSurface()
    }
    
    private func setupWaylandSurface() {
        guard let windowManager = windowManager else {
            fatalError("Window manager is not set")
        }

        // Create surface
        surface = wl_compositor_create_surface(windowManager.compositor)
        guard surface != nil else {
            fatalError("Failed to create Wayland surface")
        }
        
        // Create shell surface
        shellSurface = wl_shell_get_shell_surface(windowManager.shell, surface)
        guard shellSurface != nil else {
            fatalError("Failed to create shell surface")
        }
        
        // Set up shell surface callbacks
        wl_shell_surface_add_listener(shellSurface, &shellSurfaceListener, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        // Set initial window properties
        wl_shell_surface_set_title(shellSurface, _title)
        wl_shell_surface_set_toplevel(shellSurface)
    }
    
    // MARK: - SystemWindow Protocol
    
    var title: String {
        get { _title }
        set {
            _title = newValue
            wl_shell_surface_set_title(shellSurface, newValue)
        }
    }
    
    var size: Size {
        get { frame.size }
        set {
            frame.size = newValue
            wl_surface_commit(surface)
        }
    }
    
    var position: Point {
        get { _position }
        set {
            _position = newValue
            frame.origin = newValue
            wl_surface_commit(surface)
        }
    }
    
    func resize(to size: Size) {
        self.size = size
    }
    
    func setWindowMode(_ mode: UIWindow.Mode) {
        switch mode {
        case .windowed:
            wl_shell_surface_set_toplevel(shellSurface)
        case .fullscreen:
            fatalError("fullscreen")
            // wl_shell_surface_set_fullscreen(shellSurface, WL_SHELL_SURFACE_FULLSCREEN_METHOD_DEFAULT, 0, nil)
        }
    }
    
    func close() {
        if let shellSurface = shellSurface {
            wl_shell_surface_destroy(shellSurface)
        }
        if let surface = surface {
            wl_surface_destroy(surface)
        }
    }
    
    func show(isFocused: Bool) {
        wl_surface_commit(surface)
    }
    
    func setMinimumSize(_ size: Size) {
        _minSize = size
    }
    
    deinit {
        // close()
    }
}

// Wayland shell surface listener
nonisolated(unsafe)
private var shellSurfaceListener = wl_shell_surface_listener(
    ping: { _, shellSurface, serial in
        wl_shell_surface_pong(shellSurface, serial)
    },
    configure: { _, shellSurface, edges, width, height in
        // Handle window configuration changes
    },
    popup_done: { _, _ in
        // Handle popup done event
    }
)

#endif 