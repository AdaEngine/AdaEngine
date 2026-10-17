import CNavigation
import Foundation

extension NavigationMeshData {
    /// Encodes a single-tile asset. The envelope pins the Detour layout and float endianness.
    public func encoded() throws(NavigationError) -> Data {
        do {
            return try JSONEncoder().encode(NavigationAssetEnvelope(
                version: 1, backend: NavigationAssetEnvelope.backend, agent: agent,
                polygonCount: polygonCount, tile: Data(bytes)
            ))
        } catch {
            throw .invalidAsset
        }
    }

    /// Rejects unsupported layouts, invalid metadata, truncated sections and invalid native references.
    public init(encoded: Data) throws(NavigationError) {
        guard !encoded.isEmpty, encoded.count <= 90 * 1024 * 1024 else { throw .invalidAsset }
        let envelope: NavigationAssetEnvelope
        do {
            envelope = try JSONDecoder().decode(NavigationAssetEnvelope.self, from: encoded)
        } catch {
            throw .invalidAsset
        }
        guard envelope.version == 1, envelope.backend == NavigationAssetEnvelope.backend else { throw .unsupportedAssetVersion }
        guard envelope.agent.isValid, envelope.tile.count <= 64 * 1024 * 1024 else { throw .invalidAsset }
        var nativeAgent = AENavigationBuildSettings()
        var nativePolygonCount: Int32 = 0
        let bytes = Array(envelope.tile)
        let valid = unsafe bytes.withUnsafeBufferPointer { buffer in
            unsafe ae_navigation_validate(buffer.baseAddress, Int32(buffer.count), &nativeAgent, &nativePolygonCount)
        }
        guard valid != 0, nativePolygonCount == envelope.polygonCount,
            nativeAgent.radius == envelope.agent.radius, nativeAgent.height == envelope.agent.height,
            nativeAgent.maximumClimb == envelope.agent.maximumClimb else { throw .invalidAsset }
        self.init(bytes: bytes, agent: envelope.agent, polygonCount: envelope.polygonCount)
    }
}

private struct NavigationAssetEnvelope: Codable {
    static let backend = "detour-1.6.0-polyref32-le"
    let version: Int
    let backend: String
    let agent: NavigationAgentSettings
    let polygonCount: Int
    let tile: Data
}
