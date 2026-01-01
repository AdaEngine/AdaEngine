
#if canImport(WebGPU)
import WebGPU
import Math
import Synchronization

final class WebGPURenderBackend: RenderBackend, @unchecked Sendable {
    func createLocalRenderDevice() -> any RenderDevice {
        WebGPURenderDevice(context: context)
    }

    func createWindow(_ windowId: WindowID, for surface: any RenderSurface, size: Math.SizeInt) throws {
        try context.createWindow(windowId, for: surface, size: size)
    }

    func resizeWindow(_ windowId: WindowID, newSize: Math.SizeInt) throws {
        try context.resizeWindow(windowId, newSize: newSize)
    }

    func destroyWindow(_ windowId: WindowID) throws {
        try context.destroyWindow(windowId)
    }

    func getRenderWindow(for windowId: WindowID) -> RenderWindow? {
        fatalError()
    }

    func getRenderWindows() throws -> RenderWindows {
        fatalError()
    }

    let type: RenderBackendType = .webgpu
    let currentFrameIndex: Int = 0
    let renderDevice: RenderDevice
    private let context: WGPUContext

    init(device: WebGPU.Device, adapter: WebGPU.Adapter, instance: WebGPU.Instance) {
        self.context = WGPUContext(device: device, adapter: adapter, instance: instance)
        self.renderDevice = WebGPURenderDevice(context: context)
    }
}

extension WebGPURenderBackend {
    static func createBackend() async throws -> WebGPURenderBackend {
        let instance = createInstance(descriptor: InstanceDescriptor())
        let adapter = try await instance.requestAdapter()
        let device = try await adapter.requestDevice()

        return WebGPURenderBackend(device: device, adapter: adapter, instance: instance)
    }
}

final class WGPUContext: Sendable {
    let device: WebGPU.Device
    let adapter: WebGPU.Adapter
    let instance: WebGPU.Instance

    private let windows = Mutex<[WindowRef: RenderWindow]>([:])

    init(device: WebGPU.Device, adapter: WebGPU.Adapter, instance: WebGPU.Instance) {
        self.device = device
        self.adapter = adapter
        self.instance = instance
    }

    func createWindow(_ windowId: WindowID, for surface: any RenderSurface, size: Math.SizeInt) throws {

    }

    func resizeWindow(_ windowId: WindowID, newSize: Math.SizeInt) throws {

    }

    func destroyWindow(_ windowId: WindowID) throws {
        _ = self.windows.withLock {
            $0.removeValue(forKey: .windowId(windowId))
        }
    }

    @safe
    struct RenderWindow {
        var surface: OpaquePointer
    }
}

#endif
