
#if canImport(WebGPU)
@unsafe @preconcurrency import WebGPU
import Foundation
import Math
import Synchronization
import AdaUtils
import Logging

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

    @MainActor
    func resizeWindow(_ windowId: WindowID, newSize: Math.SizeInt, scaleFactor: Float) throws {
        try context.resizeWindow(windowId, newSize: newSize, scaleFactor: scaleFactor)
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

    init(device: WebGPU.GPUDevice, adapter: WebGPU.GPUAdapter, instance: WebGPU.GPUInstance) {
        self.context = WGPUContext(device: device, adapter: adapter, instance: instance)
        self.renderDevice = WebGPURenderDevice(context: context)
    }
}

extension WebGPURenderBackend {
    static func createBackend() throws -> WebGPURenderBackend {
        let instanceDescriptor = WebGPU.GPUInstanceDescriptor(
                requiredFeatures: [.shaderSourceSPIRV]
        )
        guard let instance = instanceDescriptor.withWGPUStruct({ descriptor in
            withUnsafePointer(to: &descriptor) { descriptor in
                WebGPU.GPUInstance(descriptor: descriptor)
            }
        }) else {
            throw WebGPUBackendError.instanceCreationFailed
        }
        let logger = Logger(label: "org.adaengine.webgpu")
        let adapter = try requestAdapter(instance: instance, logger: logger)
        let device = try requestDevice(instance: instance, adapter: adapter, logger: logger)

        return WebGPURenderBackend(device: device, adapter: adapter, instance: instance)
    }

    private static func requestAdapter(instance: WebGPU.GPUInstance, logger: Logger) throws -> WebGPU.GPUAdapter {
        var requestStatus: WebGPU.GPURequestAdapterStatus?
        var requestedAdapter: WebGPU.GPUAdapter?
        var requestMessage: String?
        _ = instance.requestAdapter(
            options: adapterOptions,
            callbackInfo: WebGPU.GPURequestAdapterCallbackInfo(mode: .allowProcessEvents) { status, adapter, message in
                requestStatus = status
                requestedAdapter = adapter
                requestMessage = message
            }
        )

        while requestStatus == nil {
            instance.processEvents()
        }

        guard requestStatus == .success, let adapter = requestedAdapter else {
            throw WebGPUBackendError.requestAdapterFailed(requestMessage ?? "unknown error")
        }

        return adapter
    }

    private static var adapterOptions: WebGPU.GPURequestAdapterOptions {
#if os(Windows)
        WebGPU.GPURequestAdapterOptions(
            powerPreference: .highPerformance,
            backendType: .D3D12
        )
#elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        WebGPU.GPURequestAdapterOptions(
            powerPreference: .highPerformance,
            backendType: .metal
        )
#elseif os(Linux)
        WebGPU.GPURequestAdapterOptions(
            powerPreference: .highPerformance,
            backendType: .vulkan
        )
#else
        WebGPU.GPURequestAdapterOptions(powerPreference: .highPerformance)
#endif
    }

    private static func logAdapterInfo(_ adapter: WebGPU.GPUAdapter, logger: Logger) {
        var info = WebGPU.GPUAdapterInfo()
        guard adapter.getInfo(info: &info) == .success else {
            logger.info("Selected WebGPU adapter, but adapter info is unavailable.")
            return
        }

        logger.info(
            "Selected WebGPU adapter: backend=\(info.backendType.rawValue) vendor=\(info.vendor) device=\(info.device) description=\(info.description)"
        )
    }

    private static func requestDevice(
        instance: WebGPU.GPUInstance,
        adapter: WebGPU.GPUAdapter,
        logger: Logger
    ) throws -> WebGPU.GPUDevice {
        var requestStatus: WebGPU.GPURequestDeviceStatus?
        var requestedDevice: WebGPU.GPUDevice?
        var requestMessage: String?
        _ = adapter.requestDevice(
            descriptor: WebGPU.GPUDeviceDescriptor(
                label: "AdaEngine WebGPU Device",
                requiredFeatures: [.depth32FloatStencil8, .float32Filterable],
                requiredLimits: nil,
                defaultQueue: WebGPU.GPUQueueDescriptor(),
                deviceLostCallbackInfo: WebGPU.GPUDeviceLostCallbackInfo(mode: .allowProcessEvents) { _, deviceLostReason, message in
                    logger.info("Device lost: \(deviceLostReason.rawValue): \(message)")
                },
                uncapturedErrorCallbackInfo: WebGPU.GPUUncapturedErrorCallbackInfo { _, logType, message in
                    logger.error("\(logType.rawValue): \(message)")
                },
                nextInChain: nil
            ),
            callbackInfo: WebGPU.GPURequestDeviceCallbackInfo(mode: .allowProcessEvents) { status, device, message in
                requestStatus = status
                requestedDevice = device
                requestMessage = message
            }
        )

        while requestStatus == nil {
            instance.processEvents()
        }

        guard requestStatus == .success, let device = requestedDevice else {
            throw WebGPUBackendError.requestDeviceFailed(requestMessage ?? "unknown error")
        }

        return device
    }
}

private enum WebGPUBackendError: LocalizedError {
    case instanceCreationFailed
    case requestAdapterFailed(String)
    case requestDeviceFailed(String)

    var errorDescription: String? {
        switch self {
        case .instanceCreationFailed:
            "Failed to create WebGPU instance."
        case .requestAdapterFailed(let message):
            "Failed to request WebGPU adapter: \(message)"
        case .requestDeviceFailed(let message):
            "Failed to request WebGPU device: \(message)"
        }
    }
}

extension WGPUStringView {
    var toString: String {
        guard let data, length > 0 else {
            return ""
        }
        return data.withMemoryRebound(to: UInt8.self, capacity: length) { data in
            String(decoding: UnsafeBufferPointer(start: data, count: length), as: UTF8.self)
        }
    }
}
#endif
