
#if canImport(WebGPU)
import WebGPU
import Math
import Synchronization
import AdaUtils

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
        context.getRenderWindow(for: windowId)
    }

    func getRenderWindows() throws -> RenderWindows {
        try context.getRenderWindows()
    }

    let type: RenderBackendType = .webgpu
    let renderDevice: RenderDevice
    private let context: WGPUContext

    init(device: WebGPU.Device, adapter: WebGPU.Adapter, instance: WebGPU.Instance) {
        self.context = WGPUContext(device: device, adapter: adapter, instance: instance)
        self.renderDevice = WebGPURenderDevice(context: context)
    }
}

extension WebGPURenderBackend {
    static func createBackend() async throws -> WebGPURenderBackend {
        let instance = createInstance(
            descriptor: InstanceDescriptor(
                requiredFeatures: [.shaderSourceSpirv]
            )
        )
        let adapter = try await instance.requestAdapter()
        let device = try await adapter.requestDevice()

        return WebGPURenderBackend(device: device, adapter: adapter, instance: instance)
    }
}
#endif
