#if os(Windows)
import CWindowsPlayer
import Foundation
import Observation

@Observable @MainActor
public final class PlayerBrowser {
    public struct Device: Identifiable {
        public let id: String
        public let name: String
        public let endpoint: PlayerEndpoint
    }
    private final class Delivery { weak var browser: PlayerBrowser?; init(_ browser: PlayerBrowser) { self.browser = browser } }
    private static var deliveries: [UInt: Delivery] = [:]
    private static var nextID: UInt = 0
    public private(set) var devices: [Device] = []
    public private(set) var status = "Looking for AdaPlayer on this network…"
    private var request: UnsafeMutableRawPointer?
    private var requestID: UInt?
    public init() {}

    public func start() {
        guard request == nil else { return }
        Self.nextID += 1
        let id = Self.nextID
        Self.deliveries[id] = Delivery(self)
        requestID = id
        request = ada_player_browse(id, windowsPlayerDiscovered)
        if request == nil {
            Self.deliveries.removeValue(forKey: id)
            status = "Discovery is unavailable. Connect with the device address and port."
        }
    }

    public func stop() {
        if let requestID { Self.deliveries.removeValue(forKey: requestID) }
        if let request { ada_player_stop_browse(request) }
        request = nil
        requestID = nil
        devices = []
    }

    fileprivate static func discovered(context: UInt, name: String, host: String, port: UInt16) {
        guard let browser = deliveries[context]?.browser else { return }
        let endpoint = PlayerEndpoint(host: host, port: port)
        let device = Device(id: host + ":" + String(port), name: name, endpoint: endpoint)
        browser.devices.removeAll { $0.id == device.id }
        browser.devices.append(device)
        browser.devices.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        browser.status = "\(browser.devices.count) AdaPlayer devices"
    }
}

private func windowsPlayerDiscovered(_ context: UInt, _ name: UnsafePointer<CChar>?, _ host: UnsafePointer<CChar>?, _ port: UInt16) {
    guard let name, let host else { return }
    let deviceName = String(cString: name).replacingOccurrences(of: "._adaplayer._tcp.local", with: "")
    let hostname = String(cString: host)
    Task { @MainActor in PlayerBrowser.discovered(context: context, name: deviceName, host: hostname, port: port) }
}
#endif
