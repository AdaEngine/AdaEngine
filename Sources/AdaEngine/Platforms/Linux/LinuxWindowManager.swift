//
//  LinuxWindowManager.swift
//  AdaEngine
//
//  Created by v.prusakov on 9/2/22.
//

#if LINUX
import Wayland

@MainActor
final class LinuxWindowManager: UIWindowManager {
    private(set) var display: OpaquePointer?
    private(set) var registry: OpaquePointer?
    private(set) var compositor: OpaquePointer?
    private(set) var shell: OpaquePointer?
    private(set) var shm: OpaquePointer?
    
    override init() {
        super.init()
        Task { @MainActor in
            setupWayland()
        }
    }
    
    private func setupWayland() {
        display = wl_display_connect(nil)
        guard display != nil else {
            fatalError("Failed to connect to Wayland display")
        }
        
        registry = wl_display_get_registry(display)
        wl_registry_add_listener(registry, &registryListener, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        wl_display_roundtrip(display)
    }
    
    override func createWindow(for window: UIWindow) {
        let minSize = UIWindow.defaultMinimumSize
        let frame = window.frame
        let size = frame.size == .zero ? minSize : frame.size
        
        let waylandView = WaylandView(
            windowId: window.id, 
            frame: frame,
            windowManager: self
        )
        let sizeInt = SizeInt(width: Int(size.width), height: Int(size.height))
        
        try? RenderEngine.shared.createWindow(window.id, for: waylandView, size: sizeInt)
        
        window.systemWindow = waylandView
        window.minSize = minSize
        
        super.createWindow(for: window)
    }
    
    override func resizeWindow(_ window: UIWindow, size: Size) {
        guard let waylandView = window.systemWindow as? WaylandView else { return }
        waylandView.resize(to: size)
    }
    
    override func setWindowMode(_ window: UIWindow, mode: UIWindow.Mode) {
        guard let waylandView = window.systemWindow as? WaylandView else { return }
        waylandView.setWindowMode(mode)
    }
    
    override func closeWindow(_ window: UIWindow) {
        guard let waylandView = window.systemWindow as? WaylandView else { return }
        waylandView.close()
    }
    
    override func showWindow(_ window: UIWindow, isFocused: Bool) {
        guard let waylandView = window.systemWindow as? WaylandView else { return }
        waylandView.show(isFocused: isFocused)
    }
    
    override func setMinimumSize(_ size: Size, for window: UIWindow) {
        guard let waylandView = window.systemWindow as? WaylandView else { return }
        waylandView.setMinimumSize(size)
    }
    
    override func updateCursor() {
        // Implement cursor updates for Wayland
    }
    
    override func getScreen(for window: UIWindow) -> Screen? {
        // Implement screen information for Wayland
        return nil
    }
    
    deinit {
        // if let registry = registry {
        //     wl_registry_destroy(registry)
        // }
        // if let display = display {
        //     wl_display_disconnect(display)
        // }
    }
}

extension WaylandView: RenderSurface {}

// Wayland registry listener
nonisolated(unsafe)
private var registryListener = wl_registry_listener(
    global: { data, registry, id, interface, version in
        let windowManager = Unmanaged<LinuxWindowManager>.fromOpaque(data!).takeUnretainedValue()
        let interfaceName = String(cString: interface!)
        
        // switch interfaceName {
        // case "wl_compositor":
        //     windowManager.compositor = wl_registry_bind(registry, id, &wl_compositor_interface, min(version, 4))
        // case "wl_shell":
        //     windowManager.shell = wl_registry_bind(registry, id, wl_shell_interface, min(version, 1))
        // case "wl_shm":
        //     windowManager.shm = wl_registry_bind(registry, id, wl_shm_interface, min(version, 1))
        // default:
        //     break
        // }
    },
    global_remove: { _, _, _ in }
)

#endif
