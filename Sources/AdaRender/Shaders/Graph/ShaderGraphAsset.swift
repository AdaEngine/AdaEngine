import AdaAssets

/// An asset-system envelope; asset metadata never becomes part of the graph document.
public struct ShaderGraphAsset: Asset {
    public var graph: ShaderGraph
    public var assetMetaInfo: AssetMetaInfo?

    public init(graph: ShaderGraph) {
        self.graph = graph
    }

    public static func extensions() -> [String] { ["shadergraph"] }

    public init(from assetDecoder: any AssetDecoder) throws {
        graph = try assetDecoder.decode(ShaderGraph.self)
    }

    public func encodeContents(with assetEncoder: any AssetEncoder) throws {
        try assetEncoder.encode(graph)
    }
}
